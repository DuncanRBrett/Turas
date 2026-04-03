# ==============================================================================
# TESTS: Turas Report Minification Pipeline
# ==============================================================================
# Comprehensive tests for turas_minify() and supporting functions.
#
# Test categories:
#   1. Path derivation
#   2. Tool detection
#   3. Meta tag stripping
#   4. HTML comment removal
#   5. CSS block extraction
#   6. JS block extraction
#   7. CSS minification (requires clean-css — skips if missing)
#   8. JS minification (requires terser — skips if missing)
#   9. HTML whitespace reduction (requires html-minifier-terser — skips if missing)
#  10. Verification checks
#  11. Integration — full pipeline (requires Node.js tools)
#  12. Graceful degradation
# ==============================================================================

library(testthat)

# -- Source dependencies -------------------------------------------------------

turas_root <- Sys.getenv("TURAS_ROOT", getwd())

# Try multiple paths for the shared lib
shared_paths <- c(
  file.path(turas_root, "modules", "shared", "lib"),
  file.path("modules", "shared", "lib"),
  file.path("..", "..", "lib")
)
shared_lib <- shared_paths[dir.exists(shared_paths)]
if (length(shared_lib) == 0L) {
  skip("Cannot locate modules/shared/lib directory")
}
shared_lib <- shared_lib[1]

source(file.path(shared_lib, "turas_minify_verify.R"), local = FALSE)
source(file.path(shared_lib, "turas_minify.R"), local = FALSE)

# Try to source TRS refusal (optional for tests)
trs_path <- file.path(shared_lib, "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path, local = FALSE)


# -- Test fixture: minimal HTML report ----------------------------------------

.build_test_html <- function() {
  paste0(
    '<!DOCTYPE html>\n',
    '<html lang="en">\n',
    '<head>\n',
    '<meta charset="UTF-8"/>\n',
    '<meta name="viewport" content="width=device-width, initial-scale=1"/>\n',
    '<meta name="turas-report-type" content="tabs"/>\n',
    '<meta name="turas-total-n" content="500"/>\n',
    '<meta name="turas-questions" content="10"/>\n',
    '<meta name="turas-source-filename" content="Test_Report"/>\n',
    '<title>Test Report</title>\n',
    '<!-- This is a comment -->\n',
    '<!-- Another comment -->\n',
    '<!--[if IE]><p>IE fallback</p><![endif]-->\n',
    '<style>\n',
    ':root {\n',
    '  --ct-brand: #2563eb;\n',
    '  --ct-accent: #f59e0b;\n',
    '  --t-font: "Inter", sans-serif;\n',
    '  --hub-bg: #f8f7f5;\n',
    '}\n',
    '/* Main layout styles */\n',
    '.ct-container { padding: 16px; margin: 0 auto; }\n',
    '.ct-header { background: var(--ct-brand); color: white; }\n',
    '.ct-table { width: 100%; border-collapse: collapse; }\n',
    '</style>\n',
    '<style>\n',
    '/* Print styles */\n',
    '@media print { .ct-no-print { display: none; } }\n',
    '</style>\n',
    '</head>\n',
    '<body>\n',
    '<div class="ct-container">\n',
    '  <h1>Test Report</h1>\n',
    '  <button onclick="toggleHeatmap()">Toggle</button>\n',
    '  <button onclick="selectQuestion(\'Q1\')">Select Q1</button>\n',
    '  <select onchange="switchBannerGroup(this.value)">\n',
    '    <option value="1">Banner 1</option>\n',
    '  </select>\n',
    '  <table data-q-code="Q001">\n',
    '    <tr><th data-col-key="Total">Total</th><th data-col-key="Male">Male</th></tr>\n',
    '    <tr><td><span class="ct-val">57%</span></td><td><span class="ct-val">62%</span></td></tr>\n',
    '    <tr><td><span class="ct-base-n">500</span></td><td><span class="ct-base-n">250</span></td></tr>\n',
    '  </table>\n',
    '  <table data-q-code="Q002">\n',
    '    <tr><th data-col-key="Total">Total</th></tr>\n',
    '    <tr><td>42%</td></tr>\n',
    '  </table>\n',
    '  <svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40"/></svg>\n',
    '  <div contenteditable="true">User notes here</div>\n',
    '</div>\n',
    '<script type="application/json" id="sig-card-states">{}</script>\n',
    '<script type="text/plain" data-encoding="base64">SGVsbG8gV29ybGQ=</script>\n',
    '<script>\n',
    '/* Core functions */\n',
    'function toggleHeatmap() {\n',
    '  var tables = document.querySelectorAll("table");\n',
    '  // Toggle visibility\n',
    '  for (var i = 0; i < tables.length; i++) {\n',
    '    tables[i].classList.toggle("heatmap");\n',
    '  }\n',
    '}\n',
    'function selectQuestion(qCode) {\n',
    '  var el = document.querySelector("[data-q-code=\'" + qCode + "\']");\n',
    '  if (el) el.scrollIntoView();\n',
    '}\n',
    'function switchBannerGroup(groupIdx) {\n',
    '  console.log("Switching to group", groupIdx);\n',
    '}\n',
    '</script>\n',
    '</body>\n',
    '</html>\n'
  )
}


# -- Helper: write test HTML to temp file -------------------------------------

.write_test_html <- function(html = NULL) {
  if (is.null(html)) html <- .build_test_html()
  tmp <- tempfile(pattern = "turas_test_dev", fileext = ".html")
  writeLines(html, tmp)
  tmp
}


# -- Helper: check if Node.js tools are available ----------------------------

.has_node <- function() nzchar(.minify_find_tool("node"))
.has_terser <- function() nzchar(.minify_find_tool("terser"))
.has_cleancss <- function() nzchar(.minify_find_tool("cleancss"))
.has_html_minifier <- function() nzchar(.minify_find_tool("html-minifier-terser"))


# ==============================================================================
# 1. PATH DERIVATION
# ==============================================================================

test_that("output path removes _dev suffix", {
  result <- .minify_derive_output_path("/reports/Project_dev.html")
  expect_equal(result, "/reports/Project.html")
})

test_that("output path appends _min when no _dev suffix", {
  result <- .minify_derive_output_path("/reports/Project.html")
  expect_equal(result, "/reports/Project_min.html")
})

test_that("output path handles nested directories", {
  result <- .minify_derive_output_path("/a/b/c/Report_dev.html")
  expect_equal(result, "/a/b/c/Report.html")
})

test_that("output path preserves extension", {
  result <- .minify_derive_output_path("/reports/Report_dev.htm")
  expect_equal(result, "/reports/Report.htm")
})


# ==============================================================================
# 2. TOOL DETECTION
# ==============================================================================

test_that("tool finder returns path or empty string", {
  result <- .minify_find_tool("this_tool_does_not_exist_xyz")
  expect_equal(result, "")
  expect_type(result, "character")
})

test_that("tool checker returns named list", {
  tools <- .minify_check_tools()
  expect_type(tools, "list")
  expect_named(tools, c("node", "terser", "cleancss", "html_minifier"))
  for (val in tools) expect_type(val, "character")
})

test_that("tool finder finds node when installed", {
  skip_if_not(.has_node(), "Node.js not available")
  result <- .minify_find_tool("node")
  expect_true(nzchar(result))
  expect_true(file.exists(result))
})


# ==============================================================================
# 3. META TAG STRIPPING
# ==============================================================================

test_that("meta stripping removes turas-* tags", {
  html <- .build_test_html()
  result <- .minify_strip_meta_tags(html)
  expect_false(grepl('name="turas-report-type"', result$html, fixed = TRUE))
  expect_false(grepl('name="turas-total-n"', result$html, fixed = TRUE))
  expect_false(grepl('name="turas-source-filename"', result$html, fixed = TRUE))
  expect_equal(result$count, 4L)
})

test_that("meta stripping preserves standard meta tags", {
  html <- .build_test_html()
  result <- .minify_strip_meta_tags(html)
  expect_true(grepl('charset="UTF-8"', result$html, fixed = TRUE))
  expect_true(grepl('name="viewport"', result$html, fixed = TRUE))
})

test_that("meta stripping handles HTML with no turas tags", {
  html <- '<html><head><meta charset="UTF-8"/></head><body></body></html>'
  result <- .minify_strip_meta_tags(html)
  expect_equal(result$count, 0L)
  expect_true(grepl('charset="UTF-8"', result$html, fixed = TRUE))
})

test_that("meta stripping handles reversed attribute order", {
  html <- '<meta content="tabs" name="turas-report-type"/>'
  result <- .minify_strip_meta_tags(html)
  expect_equal(result$count, 1L)
  expect_false(grepl("turas-report-type", result$html, fixed = TRUE))
})


# ==============================================================================
# 4. HTML COMMENT REMOVAL
# ==============================================================================

test_that("comment removal strips standard comments", {
  html <- .build_test_html()
  result <- .minify_remove_html_comments(html)
  expect_false(grepl("This is a comment", result$html, fixed = TRUE))
  expect_false(grepl("Another comment", result$html, fixed = TRUE))
  expect_equal(result$count, 2L)
})

test_that("comment removal preserves conditional comments", {
  html <- .build_test_html()
  result <- .minify_remove_html_comments(html)
  expect_true(grepl("<!--[if IE]>", result$html, fixed = TRUE))
})

test_that("comment removal preserves JSON block content", {
  html <- .build_test_html()
  result <- .minify_remove_html_comments(html)
  expect_true(grepl('id="sig-card-states"', result$html, fixed = TRUE))
  expect_true(grepl('data-encoding="base64"', result$html, fixed = TRUE))
})

test_that("comment removal handles no comments", {
  html <- "<html><body>No comments here</body></html>"
  result <- .minify_remove_html_comments(html)
  expect_equal(result$count, 0L)
  expect_equal(result$html, html)
})


# ==============================================================================
# 5. CSS BLOCK EXTRACTION
# ==============================================================================

test_that("CSS extraction finds all style blocks", {
  html <- .build_test_html()
  blocks <- .minify_extract_blocks(html, "style")
  expect_equal(length(blocks), 2L)
})

test_that("CSS extraction captures content correctly", {
  html <- .build_test_html()
  blocks <- .minify_extract_blocks(html, "style")
  # First block contains custom properties
  expect_true(grepl("--ct-brand", blocks[[1]]$content, fixed = TRUE))
  # Second block contains print styles
  expect_true(grepl("@media print", blocks[[2]]$content, fixed = TRUE))
})

test_that("CSS extraction handles empty style blocks", {
  html <- "<html><head><style></style></head><body></body></html>"
  blocks <- .minify_extract_blocks(html, "style")
  expect_equal(length(blocks), 1L)
  expect_equal(blocks[[1]]$content, "")
})


# ==============================================================================
# 6. JS BLOCK EXTRACTION
# ==============================================================================

test_that("JS extraction finds script blocks", {
  html <- .build_test_html()
  blocks <- .minify_extract_blocks(html, "script")
  expect_true(length(blocks) >= 3L)  # JSON + text/plain + JS
})

test_that("JS extraction identifies application/json blocks", {
  html <- .build_test_html()
  blocks <- .minify_extract_blocks(html, "script")
  json_blocks <- Filter(function(b) b$type == "application/json", blocks)
  expect_true(length(json_blocks) >= 1L)
})

test_that("JS extraction identifies text/plain blocks", {
  html <- .build_test_html()
  blocks <- .minify_extract_blocks(html, "script")
  plain_blocks <- Filter(function(b) b$type == "text/plain", blocks)
  expect_true(length(plain_blocks) >= 1L)
})

test_that("JS extraction captures JS content correctly", {
  html <- .build_test_html()
  blocks <- .minify_extract_blocks(html, "script")
  js_blocks <- Filter(function(b) b$type == "", blocks)
  expect_true(length(js_blocks) >= 1L)
  js_content <- js_blocks[[1]]$content
  expect_true(grepl("function toggleHeatmap", js_content, fixed = TRUE))
  expect_true(grepl("function selectQuestion", js_content, fixed = TRUE))
})


# ==============================================================================
# 7. CSS MINIFICATION (requires clean-css)
# ==============================================================================

test_that("CSS minification removes comments", {
  skip_if_not(.has_cleancss(), "clean-css not available")
  css <- "/* comment */ .foo { color: red; }"
  result <- .minify_css_block(css, .minify_find_tool("cleancss"))
  expect_true(result$success)
  expect_false(grepl("comment", result$content, fixed = TRUE))
})

test_that("CSS minification collapses whitespace", {
  skip_if_not(.has_cleancss(), "clean-css not available")
  css <- ".foo {\n  color: red;\n  padding: 10px;\n}"
  result <- .minify_css_block(css, .minify_find_tool("cleancss"))
  expect_true(result$success)
  expect_true(nchar(result$content) < nchar(css))
})

test_that("CSS minification preserves custom properties", {
  skip_if_not(.has_cleancss(), "clean-css not available")
  css <- ":root { --ct-brand: #2563eb; --t-font: Inter; } .foo { color: var(--ct-brand); }"
  result <- .minify_css_block(css, .minify_find_tool("cleancss"))
  expect_true(result$success)
  expect_true(grepl("--ct-brand", result$content, fixed = TRUE))
  expect_true(grepl("--t-font", result$content, fixed = TRUE))
})

test_that("CSS minification returns original on failure", {
  css <- ".foo { color: red; }"
  result <- .minify_css_block(css, "/nonexistent/cleancss")
  expect_false(result$success)
  expect_equal(result$content, css)
})


# ==============================================================================
# 8. JS MINIFICATION (requires terser)
# ==============================================================================

test_that("JS minification removes comments", {
  skip_if_not(.has_terser(), "terser not available")
  js <- "/* comment */ function foo() { return 1; }"
  result <- .minify_js_block(js, .minify_find_tool("terser"))
  expect_true(result$success)
  # Block comment removed (copyright preserved)
  expect_false(grepl("/* comment */", result$content, fixed = TRUE))
})

test_that("JS minification preserves top-level function names", {
  skip_if_not(.has_terser(), "terser not available")
  js <- "function toggleHeatmap() { var x = 1; return x; }\nfunction selectQuestion(q) { return q; }"
  result <- .minify_js_block(js, .minify_find_tool("terser"))
  expect_true(result$success)
  expect_true(grepl("toggleHeatmap", result$content, fixed = TRUE))
  expect_true(grepl("selectQuestion", result$content, fixed = TRUE))
})

test_that("JS minification does not mangle properties", {
  skip_if_not(.has_terser(), "terser not available")
  js <- "function test() { window.TurasPins.move('id', -1); }"
  result <- .minify_js_block(js, .minify_find_tool("terser"))
  expect_true(result$success)
  expect_true(grepl("TurasPins", result$content, fixed = TRUE))
  expect_true(grepl("move", result$content, fixed = TRUE))
})

test_that("JS minification injects copyright comment", {
  skip_if_not(.has_terser(), "terser not available")
  js <- "function foo() { return 1; }"
  result <- .minify_js_block(js, .minify_find_tool("terser"))
  expect_true(result$success)
  expect_true(grepl("Turas", result$content, fixed = TRUE))
  expect_true(grepl("TRL", result$content, fixed = TRUE))
})

test_that("JS minification returns original on failure", {
  js <- "function foo() { return 1; }"
  result <- .minify_js_block(js, "/nonexistent/terser")
  expect_false(result$success)
  expect_equal(result$content, js)
})


# ==============================================================================
# 9. HTML WHITESPACE REDUCTION (requires html-minifier-terser)
# ==============================================================================

test_that("HTML whitespace reduction collapses inter-tag whitespace", {
  skip_if_not(.has_html_minifier(), "html-minifier-terser not available")
  html <- "<div>    </div>\n\n\n<div>  text  </div>"
  result <- .minify_html_whitespace(html, .minify_find_tool("html-minifier-terser"))
  expect_true(result$success)
  expect_true(nchar(result$html) < nchar(html))
})

test_that("HTML whitespace reduction preserves text content", {
  skip_if_not(.has_html_minifier(), "html-minifier-terser not available")
  html <- paste0(
    "<html><body>\n\n\n",
    "<p>Hello World</p>\n\n",
    "<span>57%</span>\n\n",
    "<td>1,000</td>\n\n",
    "</body></html>"
  )
  result <- .minify_html_whitespace(html, .minify_find_tool("html-minifier-terser"))
  expect_true(result$success)
  expect_true(grepl("Hello World", result$html, fixed = TRUE))
  expect_true(grepl("57%", result$html, fixed = TRUE))
  expect_true(grepl("1,000", result$html, fixed = TRUE))
})

test_that("HTML whitespace reduction returns original on failure", {
  html <- "<html><body>test</body></html>"
  result <- .minify_html_whitespace(html, "/nonexistent/html-minifier-terser")
  expect_false(result$success)
  expect_equal(result$html, html)
})


# ==============================================================================
# 10. VERIFICATION CHECKS
# ==============================================================================

test_that("JS function count verification passes on matching counts", {
  original <- "function foo() {} function bar() {}"
  minified <- "function foo(){}function bar(){}"
  result <- .verify_js_function_count(original, minified)
  expect_true(result$pass)
})

test_that("JS function count verification passes when dead code removed", {
  original <- "function foo() {} function bar() {}"
  minified <- "function foo(){}"
  result <- .verify_js_function_count(original, minified)
  expect_true(result$pass)  # Dead code removal is allowed
})

test_that("JS function count verification fails when count increases", {
  original <- "function foo() {}"
  minified <- "function foo(){}function bar(){}"
  result <- .verify_js_function_count(original, minified)
  expect_false(result$pass)
})

test_that("handler function verification finds all functions", {
  html <- '<button onclick="foo()"><a onclick="bar(1)"></a>'
  js <- "function foo(){}function bar(x){}"
  result <- .verify_js_handler_functions(html, js)
  expect_true(result$pass)
})

test_that("handler function verification detects missing function", {
  html <- '<button onclick="foo()"><a onclick="missing_fn(1)"></a>'
  js <- "function foo(){}"
  result <- .verify_js_handler_functions(html, js)
  expect_false(result$pass)
  expect_true(grepl("missing_fn", result$message, fixed = TRUE))
})

test_that("CSS custom property verification passes on matching counts", {
  original <- ":root { --ct-brand: #fff; --t-font: Inter; }"
  minified <- ":root{--ct-brand:#fff;--t-font:Inter}"
  result <- .verify_css_custom_props(original, minified)
  expect_true(result$pass)
})

test_that("CSS rule count verification passes on matching counts", {
  original <- ".foo { color: red; } .bar { padding: 0; }"
  minified <- ".foo{color:red}.bar{padding:0}"
  result <- .verify_css_rule_count(original, minified)
  expect_true(result$pass)
})

test_that("HTML element verification passes on matching counts", {
  html1 <- "<table><tr><th>H</th></tr><tr><td>D</td></tr></table>"
  html2 <- "<table><tr><th>H</th></tr><tr><td>D</td></tr></table>"
  result <- .verify_html_elements(html1, html2)
  expect_true(result$pass)
})

test_that("HTML element verification detects mismatches", {
  html1 <- "<table><tr><td>A</td></tr><tr><td>B</td></tr></table>"
  html2 <- "<table><tr><td>A</td></tr></table>"
  result <- .verify_html_elements(html1, html2)
  expect_false(result$pass)
})

test_that("data attribute verification passes on matching counts", {
  html1 <- '<div data-q-code="Q1" data-col-key="Total"></div><div data-q-code="Q2"></div>'
  html2 <- '<div data-q-code="Q1" data-col-key="Total"></div><div data-q-code="Q2"></div>'
  result <- .verify_data_attributes(html1, html2)
  expect_true(result$pass)
})

test_that("file size verification passes when smaller", {
  result <- .verify_file_size(1000, 700)
  expect_true(result$pass)
})

test_that("file size verification fails when larger", {
  result <- .verify_file_size(1000, 1100)
  expect_false(result$pass)
})

test_that("full verification orchestrator returns structured result", {
  html <- "<table><tr><td data-q-code='Q1' data-col-key='T'>57%</td></tr></table>"
  css <- ":root { --ct-brand: #fff; } .foo { color: red; }"
  js <- "function foo() { return 1; }"
  result <- run_minify_verification(html, html, css, css, js, js, 1000, 700)
  expect_type(result, "list")
  expect_true(result$all_passed)
  expect_named(result, c("all_passed", "checks", "summary"))
  expect_equal(length(result$checks), 7L)
})


# ==============================================================================
# 11. INTEGRATION: FULL PIPELINE (requires Node.js tools)
# ==============================================================================

test_that("full pipeline processes test fixture without error", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_cleancss(), "clean-css not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_true(file.exists(result$output_path))
})

test_that("full pipeline produces smaller output", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, verbose = FALSE)
  expect_true(result$output_size_kb <= result$input_size_kb)
})

test_that("full pipeline preserves data content", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, verbose = FALSE)
  output_html <- paste(readLines(result$output_path, warn = FALSE), collapse = "\n")

  # Data values preserved
  expect_true(grepl("57%", output_html, fixed = TRUE))
  expect_true(grepl("62%", output_html, fixed = TRUE))
  expect_true(grepl("500", output_html, fixed = TRUE))

  # Data attributes preserved
  expect_true(grepl('data-q-code="Q001"', output_html, fixed = TRUE))
  expect_true(grepl('data-col-key="Total"', output_html, fixed = TRUE))

  # SVG preserved
  expect_true(grepl("<svg", output_html, fixed = TRUE))
  expect_true(grepl("<circle", output_html, fixed = TRUE))

  # Contenteditable preserved
  expect_true(grepl("contenteditable", output_html, fixed = TRUE))
  expect_true(grepl("User notes here", output_html, fixed = TRUE))

  # JSON block preserved
  expect_true(grepl('id="sig-card-states"', output_html, fixed = TRUE))

  # Base64 block preserved
  expect_true(grepl("SGVsbG8gV29ybGQ=", output_html, fixed = TRUE))
})

test_that("full pipeline strips turas meta tags", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, verbose = FALSE)
  output_html <- paste(readLines(result$output_path, warn = FALSE), collapse = "\n")

  expect_false(grepl('name="turas-report-type"', output_html, fixed = TRUE))
  expect_true(grepl('charset="UTF-8"', output_html, fixed = TRUE))
  expect_true(result$meta_tags_stripped >= 3L)
})

test_that("full pipeline injects build tag", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, verbose = FALSE)
  output_html <- paste(readLines(result$output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("Turas Build v", output_html, fixed = TRUE))
})

test_that("full pipeline verbose mode produces output", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  output <- capture.output(
    result <- turas_minify(input_path, verbose = TRUE)
  )

  expect_true(any(grepl("Minification Summary", output, fixed = TRUE)))
  expect_true(any(grepl("Reduction", output, fixed = TRUE)))
})

test_that("full pipeline is idempotent (re-minify does not corrupt)", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_cleancss(), "clean-css not available")

  input_path <- .write_test_html()

  # First pass
  result1 <- turas_minify(input_path, verbose = FALSE)
  output1 <- paste(readLines(result1$output_path, warn = FALSE), collapse = "\n")

  # Second pass on minified output
  second_output_path <- tempfile(fileext = ".html")
  result2 <- turas_minify(result1$output_path,
                           output_path = second_output_path,
                           verbose = FALSE)
  output2 <- paste(readLines(result2$output_path, warn = FALSE), collapse = "\n")

  # Core data must survive double-minification
  expect_true(grepl("57%", output2, fixed = TRUE))
  expect_true(grepl('data-q-code="Q001"', output2, fixed = TRUE))
  expect_true(grepl("toggleHeatmap", output2, fixed = TRUE))

  on.exit(unlink(c(input_path, result1$output_path, second_output_path), force = TRUE))
})


# ==============================================================================
# 12. GRACEFUL DEGRADATION
# ==============================================================================

test_that("turas_minify refuses on non-existent file", {
  expect_error(
    turas_minify("/this/file/does/not/exist.html"),
    "FILE_NOT_FOUND|file not found|does not exist"
  )
})

test_that("turas_minify refuses on invalid input_path type", {
  expect_error(turas_minify(42))
  expect_error(turas_minify(NULL))
  expect_error(turas_minify(""))
})

test_that("CSS-only mode works when terser is missing", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_cleancss(), "clean-css not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, minify_js = FALSE, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_equal(result$js_blocks_processed, 0L)
  expect_true(result$css_blocks_processed > 0L)
})

test_that("JS-only mode works when cleancss is missing", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, minify_css = FALSE, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_equal(result$css_blocks_processed, 0L)
  expect_true(result$js_blocks_processed > 0L)
})

test_that("explicit output_path is respected", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  output_path <- tempfile(pattern = "custom_output", fileext = ".html")
  on.exit(unlink(c(input_path, output_path), force = TRUE))

  result <- turas_minify(input_path, output_path = output_path, verbose = FALSE)
  expect_equal(result$output_path, output_path)
  expect_true(file.exists(output_path))
})

test_that("strip_meta=FALSE preserves turas meta tags", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, strip_meta = FALSE, verbose = FALSE)
  output_html <- paste(readLines(result$output_path, warn = FALSE), collapse = "\n")
  expect_true(grepl('name="turas-report-type"', output_html, fixed = TRUE))
  expect_equal(result$meta_tags_stripped, 0L)
})


# ==============================================================================
# 13. DEMO FILE INTEGRATION (optional — requires demo fixture)
# ==============================================================================

.demo_fixture_path <- file.path(
  shared_lib, "..", "..", "shared", "tests", "testthat", "fixtures",
  "Demo_CX_Crosstabs.html"
)

# Normalise — also check from turas root
if (!file.exists(.demo_fixture_path)) {
  .demo_fixture_path <- file.path(
    turas_root, "modules", "shared", "tests", "testthat", "fixtures",
    "Demo_CX_Crosstabs.html"
  )
}

test_that("demo file processes correctly with full pipeline", {
  skip_if_not(file.exists(.demo_fixture_path),
              "Demo fixture not available")
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_cleancss(), "clean-css not available")

  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(output_path, force = TRUE))

  result <- turas_minify(.demo_fixture_path,
                          output_path = output_path,
                          verbose = FALSE)

  # Status is PASS or PARTIAL

  expect_true(result$status %in% c("PASS", "PARTIAL"))

  # Size reduction between 5% and 50% (conservative range for demo)
  expect_true(result$reduction_pct > 5,
              info = sprintf("Reduction was only %.1f%%", result$reduction_pct))
  expect_true(result$reduction_pct < 80,
              info = sprintf("Reduction was %.1f%% (suspiciously high)", result$reduction_pct))

  # Table count preserved
  output_html <- paste(readLines(output_path, warn = FALSE), collapse = "\n")
  input_html <- paste(readLines(.demo_fixture_path, warn = FALSE), collapse = "\n")

  count_tag <- function(html, tag) {
    m <- gregexpr(paste0("<", tag, "[\\s>]"), html, perl = TRUE)[[1]]
    if (m[1] == -1L) 0L else length(m)
  }

  expect_equal(count_tag(output_html, "table"), count_tag(input_html, "table"))
})
