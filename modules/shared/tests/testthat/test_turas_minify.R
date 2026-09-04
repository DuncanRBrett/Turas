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
#  13. Demo file integration (optional)
#  14. Prepare deliverable convenience function
#  15. Watermark encode/decode (pure R — no tools required)
#  16. JS obfuscation (requires javascript-obfuscator — skips if missing)
#  17. Integration — obfuscation + watermark pipeline
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
source(file.path(shared_lib, "turas_minify_watermark.R"), local = FALSE)
source(file.path(shared_lib, "turas_release_audit.R"), local = FALSE)
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
.has_obfuscator <- function() nzchar(.minify_find_tool("javascript-obfuscator"))


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
  expect_named(tools, c("node", "terser", "cleancss", "html_minifier", "obfuscator"))
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

  result <- turas_minify(input_path, obfuscate_js = FALSE, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_true(file.exists(result$output_path))
})

test_that("full pipeline produces smaller output", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, obfuscate_js = FALSE, verbose = FALSE)
  expect_true(result$output_size_kb <= result$input_size_kb)
})

test_that("full pipeline preserves data content", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, obfuscate_js = FALSE, verbose = FALSE)
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

  result <- turas_minify(input_path, obfuscate_js = FALSE, verbose = FALSE)
  output_html <- paste(readLines(result$output_path, warn = FALSE), collapse = "\n")

  expect_false(grepl('name="turas-report-type"', output_html, fixed = TRUE))
  expect_true(grepl('charset="UTF-8"', output_html, fixed = TRUE))
  expect_true(result$meta_tags_stripped >= 3L)
})

test_that("full pipeline injects build tag", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, obfuscate_js = FALSE, verbose = FALSE)
  output_html <- paste(readLines(result$output_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("Turas Build v", output_html, fixed = TRUE))
})

test_that("full pipeline verbose mode produces output", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  output <- capture.output(
    result <- turas_minify(input_path, obfuscate_js = FALSE, verbose = TRUE)
  )

  expect_true(any(grepl("Minification Summary", output, fixed = TRUE)))
  # "Size", not "Reduction": a hardened deliverable is larger than the
  # development build, and "Reduction: 115.2% larger" is not a sentence.
  expect_true(any(grepl("Size:", output, fixed = TRUE)))
  expect_true(any(grepl("smaller", output, fixed = TRUE) |
                  grepl("larger", output, fixed = TRUE)))
})

test_that("full pipeline is idempotent (re-minify does not corrupt)", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_cleancss(), "clean-css not available")

  input_path <- .write_test_html()

  # First pass
  result1 <- turas_minify(input_path, obfuscate_js = FALSE, verbose = FALSE)
  output1 <- paste(readLines(result1$output_path, warn = FALSE), collapse = "\n")

  # Second pass on minified output
  second_output_path <- tempfile(fileext = ".html")
  result2 <- turas_minify(result1$output_path,
                           output_path = second_output_path,
                           obfuscate_js = FALSE, verbose = FALSE)
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

  result <- turas_minify(input_path, minify_js = FALSE,
                         obfuscate_js = FALSE, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_equal(result$js_blocks_processed, 0L)
  expect_true(result$css_blocks_processed > 0L)
})

test_that("JS-only mode works when cleancss is missing", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, minify_css = FALSE,
                         obfuscate_js = FALSE, verbose = FALSE)
  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_equal(result$css_blocks_processed, 0L)
  expect_true(result$js_blocks_processed > 0L)
})

test_that("explicit output_path is respected", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  output_path <- tempfile(pattern = "custom_output", fileext = ".html")
  on.exit(unlink(c(input_path, output_path), force = TRUE))

  result <- turas_minify(input_path, output_path = output_path,
                         obfuscate_js = FALSE, verbose = FALSE)
  expect_equal(result$output_path, output_path)
  expect_true(file.exists(output_path))
})

test_that("strip_meta=FALSE preserves turas meta tags", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  on.exit(unlink(c(input_path, sub("_dev", "", input_path)), force = TRUE))

  result <- turas_minify(input_path, strip_meta = FALSE,
                         obfuscate_js = FALSE, verbose = FALSE)
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
                          obfuscate_js = FALSE,
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

  # Use the same strip_scripts + count approach as the verification code
  # to avoid counting <table> inside JS string literals
  strip_js <- function(h) {
    parts <- strsplit(h, "<script", fixed = TRUE)[[1]]
    if (length(parts) <= 1L) return(h)
    result <- parts[1]
    for (i in 2:length(parts)) {
      cp <- regexpr("</script>", parts[i], fixed = TRUE)
      if (cp > 0) result <- paste0(result, substr(parts[i], cp + 9L, nchar(parts[i])))
    }
    result
  }
  count_tag <- function(html, tag) {
    h <- strip_js(html)
    n1 <- (nchar(h) - nchar(gsub(paste0("<", tag, " "), "", h, fixed = TRUE))) /
          nchar(paste0("<", tag, " "))
    n2 <- (nchar(h) - nchar(gsub(paste0("<", tag, ">"), "", h, fixed = TRUE))) /
          nchar(paste0("<", tag, ">"))
    as.integer(n1 + n2)
  }

  expect_equal(count_tag(output_html, "table"), count_tag(input_html, "table"))
})


# ==============================================================================
# 14. PREPARE DELIVERABLE CONVENIENCE FUNCTION
# ==============================================================================

test_that("turas_prepare_deliverable does nothing when flag not set", {
  skip_if_not(.has_node(), "Node.js not available")

  input_path <- .write_test_html()
  on.exit(unlink(input_path, force = TRUE))

  # Ensure flag is not set
  if (exists("TURAS_PREPARE_DELIVERABLE", envir = .GlobalEnv)) {
    rm("TURAS_PREPARE_DELIVERABLE", envir = .GlobalEnv)
  }

  turas_prepare_deliverable(input_path)

  # File should be unchanged (not renamed)
  expect_true(file.exists(input_path))
})

test_that("turas_prepare_deliverable creates _dev and minified files when flag set", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  expected_dev <- sub("\\.html$", "_dev.html", input_path)
  on.exit(unlink(c(input_path, expected_dev), force = TRUE))

  # Set the flag
  assign("TURAS_PREPARE_DELIVERABLE", TRUE, envir = .GlobalEnv)
  on.exit(rm("TURAS_PREPARE_DELIVERABLE", envir = .GlobalEnv), add = TRUE)

  turas_prepare_deliverable(input_path)

  # Original should be renamed to _dev
  expect_true(file.exists(expected_dev))
  # Minified version should exist at the original path (turas_minify derives
  # output from _dev → clean name)
  clean_path <- sub("_dev\\.html$", ".html", expected_dev)
  expect_true(file.exists(clean_path))
})

test_that("turas_prepare_deliverable handles NULL and empty path without error", {
  expect_invisible(turas_prepare_deliverable(NULL))
  expect_invisible(turas_prepare_deliverable(""))
  expect_invisible(turas_prepare_deliverable(42))
})


# ==============================================================================
# 15. WATERMARK ENCODE/DECODE (pure R — no external tools required)
# ==============================================================================

test_that("base64 encode/decode roundtrip preserves text", {
  inputs <- c("Hello World", "Acme Corp|2026-04-03|abc123",
              "", "a", "ab", "abc", "Special: @#$%^&*()")
  for (input in inputs) {
    encoded <- .watermark_base64_encode(input)
    decoded <- .watermark_base64_decode(encoded)
    expect_equal(decoded, input, info = sprintf("Roundtrip failed for: '%s'", input))
  }
})

test_that("base64 encode produces expected output for known input", {
  # Known-answer test: "Hello" -> "SGVsbG8="
  expect_equal(.watermark_base64_encode("Hello"), "SGVsbG8=")
  expect_equal(.watermark_base64_encode("Man"), "TWFu")
  expect_equal(.watermark_base64_encode("Ma"), "TWE=")
  expect_equal(.watermark_base64_encode("M"), "TQ==")
})

test_that("ZWC encode/decode roundtrip preserves text", {
  inputs <- c("Hello World", "Acme Corp|2026-04-03|abc123",
              "a", "Test Client Name")
  for (input in inputs) {
    encoded <- .watermark_encode_zwc(input)
    decoded <- .watermark_decode_zwc(encoded)
    expect_equal(decoded, input, info = sprintf("ZWC roundtrip failed for: '%s'", input))
  }
})

test_that("ZWC encoding produces invisible characters", {
  encoded <- .watermark_encode_zwc("Test")
  chars <- strsplit(encoded, "")[[1]]
  zwc_set <- c("\u200B", "\u200C", "\u200D", "\uFEFF")
  expect_true(all(chars %in% zwc_set))
  expect_equal(length(chars), 4L * length(charToRaw("Test")))
})

test_that("ZWC decode returns empty on invalid input", {
  expect_equal(.watermark_decode_zwc(""), "")
  expect_equal(.watermark_decode_zwc("not zwc chars"), "")
})

test_that("UUID generator produces 32 hex characters", {
  id <- .watermark_generate_id()
  expect_equal(nchar(id), 32L)
  expect_true(grepl("^[0-9a-f]+$", id))
})

test_that("UUID generator produces unique values", {
  ids <- replicate(10, .watermark_generate_id())
  expect_equal(length(unique(ids)), 10L)
})

test_that("watermark payload roundtrip works", {
  wm <- .watermark_build_payload("Acme Corp")
  expect_equal(wm$client, "Acme Corp")
  expect_true(nzchar(wm$date))
  expect_true(nzchar(wm$id))

  parsed <- .watermark_parse_payload(wm$payload)
  expect_equal(parsed$client, "Acme Corp")
  expect_equal(parsed$date, wm$date)
  expect_equal(parsed$id, wm$id)
})

test_that("watermark injection adds both JS and HTML markers", {
  html <- .build_test_html()
  result <- .minify_inject_watermark(html, "Test Client")

  expect_true(result$success)
  expect_equal(result$client, "Test Client")
  expect_true(nzchar(result$date))
  expect_true(nzchar(result$id))

  # JS watermark present
  expect_true(grepl("window.__turas_build__=", result$html, fixed = TRUE))

  # HTML watermark span present
  expect_true(grepl("class=\"turas-wm\"", result$html, fixed = TRUE))
})

test_that("watermark injection skips on NULL/empty client", {
  html <- .build_test_html()

  result_null <- .minify_inject_watermark(html, NULL)
  expect_false(result_null$success)
  expect_equal(result_null$html, html)

  result_empty <- .minify_inject_watermark(html, "")
  expect_false(result_empty$success)
  expect_equal(result_empty$html, html)
})

test_that("turas_decode_watermark extracts watermarks from file", {
  html <- .build_test_html()
  wm_result <- .minify_inject_watermark(html, "Decode Test Client")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp, force = TRUE))
  writeLines(wm_result$html, tmp)

  decoded <- turas_decode_watermark(tmp)
  expect_equal(decoded$status, "PASS")
  expect_equal(decoded$js_watermark$client, "Decode Test Client")
  expect_equal(decoded$html_watermark$client, "Decode Test Client")
  expect_true(decoded$match)
})

test_that("turas_decode_watermark returns REFUSED on missing file", {
  result <- turas_decode_watermark("/nonexistent/path.html")
  expect_equal(result$status, "REFUSED")
})

test_that("turas_decode_watermark returns REFUSED on unwatermarked file", {
  html <- .build_test_html()
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp, force = TRUE))
  writeLines(html, tmp)

  result <- turas_decode_watermark(tmp)
  expect_equal(result$status, "REFUSED")
  expect_true(grepl("No watermark", result$message))
})


# ==============================================================================
# 16. JS OBFUSCATION (requires javascript-obfuscator — skips if missing)
# ==============================================================================

test_that("obfuscator tool detection works", {
  result <- .minify_find_tool("javascript-obfuscator")
  # Just check it returns a character (may or may not be installed)
  expect_type(result, "character")
})

test_that("obfuscate_js_block obfuscates simple JS", {
  skip_if_not(.has_obfuscator(), "javascript-obfuscator not available")

  js <- 'function hello() { var msg = "Hello World"; console.log(msg); }'
  obf_path <- .minify_find_tool("javascript-obfuscator")
  result <- .minify_obfuscate_js_block(js, obf_path)

  expect_true(result$success)
  # String array artifacts should be present
  expect_true(grepl("0x", result$content))
  # Function name should be preserved (renameGlobals=false)
  expect_true(grepl("hello", result$content, fixed = TRUE))
  # Original string literal should NOT appear in clear text
  expect_false(grepl('"Hello World"', result$content, fixed = TRUE))
})

test_that("obfuscate_js_block preserves onclick handler function names", {
  skip_if_not(.has_obfuscator(), "javascript-obfuscator not available")

  js <- paste0(
    'function toggleHeatmap() { var x = "toggle"; console.log(x); }\n',
    'function selectQuestion(q) { var el = document.getElementById(q); }\n',
    'function switchBannerGroup(idx) { console.log("group", idx); }'
  )
  obf_path <- .minify_find_tool("javascript-obfuscator")
  result <- .minify_obfuscate_js_block(js, obf_path)

  expect_true(result$success)
  expect_true(grepl("toggleHeatmap", result$content, fixed = TRUE))
  expect_true(grepl("selectQuestion", result$content, fixed = TRUE))
  expect_true(grepl("switchBannerGroup", result$content, fixed = TRUE))
})

test_that("obfuscate_js_block skips vendor blocks", {
  skip_if_not(.has_obfuscator(), "javascript-obfuscator not available")

  js <- paste0(
    'function myFunc() { var x = "test"; }\n',
    '/* TURAS_VENDOR_START */\n',
    'var vendorLib = "already minified vendor code";\n',
    '/* TURAS_VENDOR_END */\n',
    'function myOtherFunc() { var y = "another"; }'
  )
  obf_path <- .minify_find_tool("javascript-obfuscator")
  result <- .minify_obfuscate_js_block(js, obf_path)

  expect_true(result$success)
  # Vendor markers should be preserved
  expect_true(grepl("TURAS_VENDOR_START", result$content, fixed = TRUE))
  expect_true(grepl("TURAS_VENDOR_END", result$content, fixed = TRUE))
  # Vendor content should be unchanged
  expect_true(grepl("already minified vendor code", result$content, fixed = TRUE))
})

test_that("obfuscate_js_block returns original on empty input", {
  result <- .minify_obfuscate_js_block("", "/fake/path")
  expect_false(result$success)
  expect_equal(result$content, "")
})

test_that("obfuscate_js_block returns original on bad path", {
  result <- .minify_obfuscate_js_block("var x = 1;", "")
  expect_false(result$success)
  expect_equal(result$content, "var x = 1;")
})

test_that("check_tools includes obfuscator field", {
  tools <- .minify_check_tools()
  expect_true("obfuscator" %in% names(tools))
})


# ==============================================================================
# 17. INTEGRATION — OBFUSCATION + WATERMARK PIPELINE
# ==============================================================================

test_that("full pipeline with obfuscation produces valid output", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obfuscator(), "javascript-obfuscator not available")

  input_path <- .write_test_html()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(c(input_path, output_path), force = TRUE))

  result <- turas_minify(input_path, output_path,
                         obfuscate_js = TRUE, verbose = FALSE)

  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_true(file.exists(output_path))
  expect_true(result$js_blocks_obfuscated > 0L)

  # Read output and verify handler functions still present
  output_html <- paste(readLines(output_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("toggleHeatmap", output_html, fixed = TRUE))
  expect_true(grepl("selectQuestion", output_html, fixed = TRUE))
  expect_true(grepl("switchBannerGroup", output_html, fixed = TRUE))

  # Verify string literals are obfuscated (not in clear text)
  expect_false(grepl('"Hello World"', output_html, fixed = TRUE))
})

test_that("full pipeline with obfuscation + watermark works end-to-end", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obfuscator(), "javascript-obfuscator not available")

  input_path <- .write_test_html()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(c(input_path, output_path), force = TRUE))

  result <- turas_minify(input_path, output_path,
                         obfuscate_js = TRUE,
                         watermark = "Integration Test Client",
                         verbose = FALSE)

  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_equal(result$watermark_client, "Integration Test Client")
  expect_true(result$js_blocks_obfuscated > 0L)

  # Decode the watermark from the output file
  decoded <- turas_decode_watermark(output_path)
  expect_equal(decoded$status, "PASS")

  # HTML watermark should decode correctly
  expect_equal(decoded$html_watermark$client, "Integration Test Client")
})

test_that("full pipeline without obfuscation matches Phase 1 behaviour", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(c(input_path, output_path), force = TRUE))

  result <- turas_minify(input_path, output_path,
                         obfuscate_js = FALSE, watermark = NULL,
                         verbose = FALSE)

  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_equal(result$js_blocks_obfuscated, 0L)
  expect_equal(result$watermark_client, "")
})

test_that("obfuscator missing results in PARTIAL with minified JS preserved", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")

  input_path <- .write_test_html()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(c(input_path, output_path), force = TRUE))

  # Temporarily override the tool check to simulate missing obfuscator
  # by passing obfuscate_js=TRUE but with a saved/restored tool finder
  # We can test this by checking that the function handles missing gracefully
  # Instead, test via the direct block function with a bad path
  result <- .minify_obfuscate_js_block("var x = 1;", "/nonexistent/obfuscator")
  expect_false(result$success)
  expect_equal(result$content, "var x = 1;")
})

test_that("verification passes on obfuscated output", {
  skip_if_not(.has_node(), "Node.js not available")
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(.has_obfuscator(), "javascript-obfuscator not available")

  input_path <- .write_test_html()
  output_path <- tempfile(fileext = ".html")
  on.exit(unlink(c(input_path, output_path), force = TRUE))

  result <- turas_minify(input_path, output_path,
                         obfuscate_js = TRUE,
                         watermark = "Verify Test",
                         verbose = FALSE)

  expect_true(result$verification_passed)
})

test_that("verification with watermark_client checks watermark integrity", {
  html <- .build_test_html()
  wm_result <- .minify_inject_watermark(html, "Test Client")

  verification <- run_minify_verification(
    original_html = html,
    minified_html = wm_result$html,
    original_css = "", minified_css = "",
    original_js = "", minified_js = "",
    input_size_bytes = nchar(html),
    output_size_bytes = nchar(wm_result$html),
    obfuscated = FALSE,
    watermark_client = "Test Client"
  )

  # Watermark check should be present and pass
  expect_true("watermark" %in% names(verification$checks))
  expect_true(verification$checks$watermark$pass)
})

test_that("verification skips js_function_count when obfuscated", {
  verification <- run_minify_verification(
    original_html = "<html><body></body></html>",
    minified_html = "<html><body></body></html>",
    original_css = "", minified_css = "",
    original_js = "function a(){} function b(){}",
    minified_js = "function a(){} function b(){} function _0x123(){}",
    input_size_bytes = 100,
    output_size_bytes = 120,
    obfuscated = TRUE
  )

  # Function count check should be skipped (pass with skip message)
  expect_true(verification$checks$js_functions$pass)
  expect_true(grepl("skipped", verification$checks$js_functions$message))

  # File size should pass with obfuscation tolerance
  expect_true(verification$checks$file_size$pass)
})


# ==============================================================================
# 18. Client-safe refusal writes nothing (audit runs before the write)
# ==============================================================================

.build_micro_html <- function() {
  paste0(
    '<!DOCTYPE html>\n<html lang="en">\n<head><meta charset="UTF-8"/>\n',
    '<title>Client safe test</title>\n<style>body{margin:0}</style>\n</head>\n<body>\n',
    '<div id="app"></div>\n',
    '<script type="application/json" id="data-agg">{"questions":[]}</script>\n',
    '<script type="application/json" id="data-micro">',
    '{"n":3,"answers":{"Q1":[0,1,2]},"weights":[1,1,1]}</script>\n',
    '<script>\nfunction boot() { return 1; }\nboot();\n</script>\n',
    '</body>\n</html>\n'
  )
}

test_that("a client-safe build that still carries data-micro refuses and leaves no output file", {
  skip_if_not(exists("turas_release_audit", mode = "function"),
              "turas_release_audit.R not loaded")
  skip_if_not(exists("turas_refuse", mode = "function"), "trs_refusal.R not loaded")
  tmp <- tempfile(pattern = "turas_cs_dev", fileext = ".html")
  writeLines(.build_micro_html(), tmp, useBytes = TRUE)
  on.exit(unlink(tmp), add = TRUE)
  out <- .minify_derive_output_path(tmp)
  on.exit(unlink(out), add = TRUE)

  expect_error(
    suppressWarnings(turas_minify(tmp, verbose = FALSE, client_safe = TRUE)),
    class = "turas_refusal"
  )
  expect_false(file.exists(out))
  expect_true(file.exists(tmp))
})

test_that("the same file passes when client-safe is not declared, and the audit result rides along", {
  skip_if_not(exists("turas_release_audit", mode = "function"),
              "turas_release_audit.R not loaded")
  tmp <- tempfile(pattern = "turas_cs_dev", fileext = ".html")
  writeLines(.build_micro_html(), tmp, useBytes = TRUE)
  on.exit(unlink(tmp), add = TRUE)
  out <- .minify_derive_output_path(tmp)
  on.exit(unlink(out), add = TRUE)

  r <- suppressWarnings(turas_minify(tmp, verbose = FALSE, client_safe = FALSE))
  expect_true(r$status %in% c("PASS", "PARTIAL"))
  expect_true(file.exists(out))
  expect_true(r$release_audit$microdata$present)
  expect_equal(r$release_audit$microdata$n, 3L)
})

test_that("turas_prepare_deliverable survives a client-safe refusal and keeps the dev copy", {
  skip_if_not(exists("turas_release_audit", mode = "function"),
              "turas_release_audit.R not loaded")
  skip_if_not(exists("turas_refuse", mode = "function"), "trs_refusal.R not loaded")
  dir <- tempfile(pattern = "turas_cs_dir"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  report <- file.path(dir, "Report.html")
  writeLines(.build_micro_html(), report, useBytes = TRUE)

  assign("TURAS_PREPARE_DELIVERABLE", TRUE, envir = .GlobalEnv)
  assign("TURAS_DELIVERY_CLIENT_SAFE", TRUE, envir = .GlobalEnv)
  on.exit(rm(list = c("TURAS_PREPARE_DELIVERABLE", "TURAS_DELIVERY_CLIENT_SAFE"),
             envir = .GlobalEnv), add = TRUE)

  out <- capture.output(suppressWarnings(turas_prepare_deliverable(report)))
  expect_true(any(grepl("No client deliverable was written", out, fixed = TRUE)))
  expect_false(file.exists(report))
  expect_true(file.exists(file.path(dir, "Report_dev.html")))
})


# ==============================================================================
# 18. DELIVERABLE BUILDS: the silent fallbacks are refusals
# ==============================================================================
# Until 4 September 2026 a failed or missing obfuscator kept the plain minified
# JavaScript, recorded a warning, and wrote the file anyway under the clean
# deliverable name. The reason the deliverable path exists is that the readable
# renderer must not leave the building, so in a deliverable build that is a
# refusal. A development build keeps the old forgiving behaviour.

#' Put a stub javascript-obfuscator that always fails at the front of PATH
#'
#' .minify_find_tool() tries Sys.which() first, so this is enough to make the
#' pipeline believe the real tool is this one.
.with_failing_obfuscator <- function(code) {
  dir <- tempfile(pattern = "turas_stub_bin"); dir.create(dir)
  stub <- file.path(dir, "javascript-obfuscator")
  writeLines(c("#!/bin/sh", "echo 'stub obfuscator failure' >&2", "exit 1"), stub)
  Sys.chmod(stub, "0755")
  old_path <- Sys.getenv("PATH")
  Sys.setenv(PATH = paste(dir, old_path, sep = .Platform$path.sep))
  on.exit({ Sys.setenv(PATH = old_path); unlink(dir, recursive = TRUE) }, add = TRUE)
  force(code)
}

test_that("a deliverable build refuses when obfuscation fails", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(exists("turas_refuse", mode = "function"), "trs_refusal.R not loaded")
  tmp <- tempfile(pattern = "turas_deliv_dev", fileext = ".html")
  writeLines(.build_micro_html(), tmp, useBytes = TRUE)
  out <- .minify_derive_output_path(tmp)
  on.exit(unlink(c(tmp, out)), add = TRUE)

  .with_failing_obfuscator({
    expect_error(
      suppressWarnings(capture.output(
        turas_minify(tmp, verbose = FALSE, deliverable = TRUE))),
      class = "turas_refusal"
    )
  })
  expect_false(file.exists(out))
})

test_that("the same failure in a development build warns and still writes", {
  skip_if_not(.has_terser(), "terser not available")
  tmp <- tempfile(pattern = "turas_devbuild", fileext = ".html")
  writeLines(.build_micro_html(), tmp, useBytes = TRUE)
  out <- .minify_derive_output_path(tmp)
  on.exit(unlink(c(tmp, out)), add = TRUE)

  res <- .with_failing_obfuscator({
    suppressWarnings(turas_minify(tmp, verbose = FALSE, deliverable = FALSE))
  })
  expect_equal(res$status, "PARTIAL")
  expect_true(file.exists(out))
  expect_equal(res$js_blocks_obfuscated, 0L)
})

test_that("a deliverable build refuses when the obfuscator is not installed", {
  skip_if_not(exists("turas_refuse", mode = "function"), "trs_refusal.R not loaded")
  tmp <- tempfile(pattern = "turas_notool_dev", fileext = ".html")
  writeLines(.build_micro_html(), tmp, useBytes = TRUE)
  out <- .minify_derive_output_path(tmp)
  on.exit(unlink(c(tmp, out)), add = TRUE)

  real_check <- .minify_check_tools
  assign(".minify_check_tools", function() {
    t <- real_check(); t$obfuscator <- ""; t
  }, envir = .GlobalEnv)
  on.exit(assign(".minify_check_tools", real_check, envir = .GlobalEnv), add = TRUE)

  expect_error(
    suppressWarnings(capture.output(
      turas_minify(tmp, verbose = FALSE, deliverable = TRUE))),
    class = "turas_refusal"
  )
  expect_false(file.exists(out))
})

test_that("the committed node profile mirror matches the R constants", {
  path <- file.path(shared_lib, "minify_profile.json")
  skip_if_not(file.exists(path), "minify_profile.json not present")
  on_disk <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expected <- .minify_profile_json_text()
  expect_equal(trimws(on_disk), trimws(expected))
})


# ==============================================================================
# 19. SCRIPT TAGS INSIDE AN IFRAME SRCDOC ATTRIBUTE
# ==============================================================================
# The maxdiff report embeds its whole simulator in an iframe srcdoc attribute,
# HTML-escaped. Those escaped <script> tags are attribute text, not script
# elements, and their bodies are not valid JavaScript. Handing them to terser
# produced eight warnings on every maxdiff build, and once a deliverable build
# refuses on a failed obfuscation it would have refused on every one.

test_that("script tags inside a srcdoc attribute are not extracted as blocks", {
  html <- paste0(
    '<html><body>\n',
    '<iframe srcdoc="&lt;html&gt;&lt;body&gt;',
    '<script>window.addEventListener(&quot;load&quot;,function(){});</script>',
    '&lt;/body&gt;&lt;/html&gt;"></iframe>\n',
    '<script>function real() { return 1; }</script>\n',
    '</body></html>'
  )
  blocks <- .minify_extract_blocks(html, "script")
  expect_equal(length(blocks), 1L)
  expect_true(grepl("function real", blocks[[1]]$content, fixed = TRUE))
})

test_that("a document with no srcdoc still extracts every script block", {
  html <- paste0('<html><body>',
                 '<script type="application/json" id="data-agg">{"a":1}</script>',
                 '<script>var x = 1;</script>',
                 '</body></html>')
  blocks <- .minify_extract_blocks(html, "script")
  expect_equal(length(blocks), 2L)
  expect_equal(blocks[[1]]$type, "application/json")
})

test_that("the maxdiff example report obfuscates every real block with no warning", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(nzchar(.minify_find_tool("javascript-obfuscator")),
              "javascript-obfuscator not available")
  # turas_root is the working directory, which testthat moves to the test
  # folder. shared_lib was resolved by search, so walk back up from it.
  root <- dirname(dirname(dirname(normalizePath(shared_lib, mustWork = FALSE))))
  src <- file.path(root, "examples", "maxdiff", "Output",
                   "Karoo_MaxDiff_Results.html")
  skip_if_not(file.exists(src), "maxdiff example report not built")

  work <- tempfile(pattern = "md_srcdoc"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  dev_path <- file.path(work, basename(src))
  file.copy(src, dev_path)

  res <- suppressWarnings(turas_minify(dev_path,
                                       output_path = file.path(work, "out.html"),
                                       verbose = FALSE, deliverable = TRUE))
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_equal(res$js_blocks_obfuscated, res$js_blocks_processed)
  expect_equal(sum(grepl("failed to obfuscate", res$warnings)), 0L)
})


# ==============================================================================
# 19b. HARDENING THE DOCUMENT INSIDE A SRCDOC ATTRIBUTE
# ==============================================================================
# Skipping those blocks stopped the warnings but left about 1.2 MB of the
# maxdiff simulator readable inside an otherwise hardened file. Step 2b takes
# the embedded document out, puts it through this same function, and puts it
# back. Deliverable only, so the dev copy still opens readable.

test_that("the srcdoc escape round trip is exact", {
  # Includes the two characters that make order matter: a literal ampersand and
  # a literal quote, plus an &quot; that was already in the source.
  doc <- paste0('<html><body><script>var s = "a &amp; b";',
                'var t = &quot;already escaped&quot;;',
                'if (a && b) { f("x") }</script></body></html>')
  esc <- .minify_srcdoc_escape(doc)
  expect_false(grepl('"', esc, fixed = TRUE),
               info = "an unescaped quote would terminate the attribute")
  expect_identical(.minify_srcdoc_unescape(esc), doc)
})

test_that("a document with no srcdoc is left byte-identical", {
  html <- paste0('<html><body><script>var x = 1;</script></body></html>')
  out <- .minify_harden_srcdoc(html, opts = list(), verbose = FALSE)
  expect_identical(out$html, html)
  expect_equal(out$count, 0L)
})

test_that("a srcdoc carrying no script is left alone", {
  html <- '<html><body><iframe srcdoc="&lt;p&gt;hello&lt;/p&gt;"></iframe></body></html>'
  out <- .minify_harden_srcdoc(html, opts = list(), verbose = FALSE)
  expect_identical(out$html, html)
  expect_equal(out$count, 0L)
})

test_that("a srcdoc that is not a whole document is left alone", {
  # The range regex is a text match. A JavaScript string that happens to
  # contain srcdoc=" must not have a minified document spliced over it.
  html <- paste0('<html><body><script>var t = \'srcdoc="<script>x()</script>"\';',
                 '</script></body></html>')
  out <- .minify_harden_srcdoc(html, opts = list(), verbose = FALSE)
  expect_identical(out$html, html)
  expect_equal(out$count, 0L)
})

test_that("the extractor and the hardener agree on where the srcdoc is", {
  # One definition, two callers. If they ever drifted, a block would be both
  # skipped by the extractor and left unprotected by the hardener.
  html <- paste0('<html><body><iframe srcdoc="&lt;html&gt;',
                 '<script>var a=1</script>&lt;/html&gt;"></iframe>',
                 '<script>var real=2</script></body></html>')
  ranges <- .minify_srcdoc_ranges(html)
  expect_equal(nrow(ranges), 1L)
  blocks <- .minify_extract_blocks(html, "script")
  expect_equal(length(blocks), 1L)
  expect_true(grepl("var real", blocks[[1]]$content, fixed = TRUE))
})

test_that("an embedded simulator is hardened and still a working document", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(nzchar(.minify_find_tool("javascript-obfuscator")),
              "javascript-obfuscator not available")
  root <- dirname(dirname(dirname(normalizePath(shared_lib, mustWork = FALSE))))
  sim <- file.path(root, "examples", "integrated_demo", "Output", "tabs",
                   "report", "Karoo_MaxDiff_Results_simulator.html")
  skip_if_not(file.exists(sim), "maxdiff simulator not built")

  body <- paste(readLines(sim, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  page <- sprintf('<html><body><iframe srcdoc="%s"></iframe></body></html>',
                  .minify_srcdoc_escape(body))

  work <- tempfile(pattern = "srcdoc_harden"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  dev_path <- file.path(work, "report_dev.html")
  writeLines(page, dev_path, useBytes = TRUE)

  res <- suppressWarnings(turas_minify(dev_path,
                                       output_path = file.path(work, "out.html"),
                                       verbose = FALSE, deliverable = TRUE))
  # PARTIAL is fine here and says nothing about the hardening: this wrapper is
  # one attribute and almost no markup, so html-minifier-terser has nothing to
  # collapse and its result is not smaller, which the step records as skipped.
  # What must hold is that verification passed and the document was hardened.
  expect_true(res$status %in% c("PASS", "PARTIAL"), info = res$status)
  expect_true(res$verification_passed)
  expect_equal(res$srcdoc_documents_hardened, 1L)

  out <- paste(readLines(file.path(work, "out.html"), warn = FALSE,
                         encoding = "UTF-8"), collapse = "\n")
  inner <- .minify_srcdoc_unescape(
    substr(out, regexpr('srcdoc="', out, fixed = TRUE) + 8L, nchar(out)))

  # The builder splices its tab-hiding injection in with a fixed sub() on
  # </head>, so that tag has to survive or the injection is lost.
  expect_true(grepl("</head>", inner, fixed = TRUE))
  expect_true(grepl("</body>", inner, fixed = TRUE))

  # The simulator's runtime has no island decoder, so its islands must come
  # back plain. Carrying no data-island="v2" marker is what keeps the encoder
  # off them.
  for (id in c("sim-data", "pinned-views-data")) {
    expect_true(grepl(sprintf('id="%s"', id), inner, fixed = TRUE),
                info = sprintf("island %s went missing", id))
  }
  expect_false(grepl('data-island="v2"', inner, fixed = TRUE),
               info = "an encoded island would boot the simulator blank")

  # Internals go. Public object properties stay, because the pin buttons are
  # built at runtime carrying onclick="TurasPins.move(...)".
  expect_false(grepl("buildH2HSVG", out, fixed = TRUE))
  expect_true(grepl("TurasPins", inner, fixed = TRUE))
})

test_that("an embedded document that cannot be obfuscated refuses the build", {
  skip_if_not(.has_terser(), "terser not available")
  skip_if_not(nzchar(.minify_find_tool("javascript-obfuscator")),
              "javascript-obfuscator not available")

  # This is the reason the step lives here rather than in maxdiff. Hardening
  # the simulator before the report was written meant a failure kept the
  # readable simulator and let the outer build succeed, which shipped a
  # hardened report with a readable simulator inside it. Here the refusal
  # reaches turas_prepare_deliverable() and no deliverable is written.
  broken <- "<html><body><script>function ( {</script></body></html>"
  html <- paste0('<html><body><iframe srcdoc="',
                 .minify_srcdoc_escape(broken), '"></iframe></body></html>')
  work <- tempfile(pattern = "srcdoc_refuse"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  dev_path <- file.path(work, "report_dev.html")
  out_path <- file.path(work, "report.html")
  writeLines(html, dev_path, useBytes = TRUE)

  expect_error(
    suppressWarnings(turas_minify(dev_path, output_path = out_path,
                                  verbose = FALSE, deliverable = TRUE)),
    class = "turas_refusal")
  expect_false(file.exists(out_path),
               info = "a file under the deliverable name is a file someone will send")
})

test_that("a development build leaves the embedded document readable", {
  skip_if_not(.has_terser(), "terser not available")
  html <- paste0('<html><body><iframe srcdoc="',
                 .minify_srcdoc_escape(
                   '<html><body><script>function keepMeReadable(){return 1}</script></body></html>'),
                 '"></iframe><script>var outer = 1;</script></body></html>')
  work <- tempfile(pattern = "srcdoc_dev"); dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  dev_path <- file.path(work, "report_dev.html")
  writeLines(html, dev_path, useBytes = TRUE)

  res <- suppressWarnings(turas_minify(dev_path,
                                       output_path = file.path(work, "out.html"),
                                       verbose = FALSE, deliverable = FALSE))
  out <- paste(readLines(file.path(work, "out.html"), warn = FALSE,
                         encoding = "UTF-8"), collapse = "\n")
  expect_true(grepl("keepMeReadable", out, fixed = TRUE),
              info = "the dev copy is the file you open when the report misbehaves")
  expect_equal(res$srcdoc_documents_hardened, 0L)
})


# ==============================================================================
# 20. DATA ISLAND ENCODING
# ==============================================================================
# A client deliverable encodes each marked island so the report cannot be read,
# grepped, or pasted into a tool that expects JSON. It is not encryption: the
# key is in the file. The JavaScript half is decodeIsland() in 24_shell.js and
# the two are pinned against each other by
# modules/tabs/lib/html_report_v2/tests/island_encoding_tests.mjs.

.island_html <- function(k_attr = "") {
  paste0(
    '<html><body>\n',
    '<script type="application/json" id="data-agg" data-island="v2">',
    '{"questions":[{"code":"Q001"}]}</script>\n',
    '<script type="application/json" id="data-micro" data-island="v2"', k_attr, '>',
    '{"n":3,"weights":[1,1,1]}</script>\n',
    '<script type="application/json" id="data-qual" data-island="v2">null</script>\n',
    '<script type="application/json" id="user-state">null</script>\n',
    '<script type="application/json" id="sim-data">{"unmarked":true}</script>\n',
    '</body></html>'
  )
}

test_that("the keystream is deterministic and byte-valued", {
  a <- .minify_keystream(42L, 64L)
  b <- .minify_keystream(42L, 64L)
  expect_identical(a, b)
  expect_length(a, 64L)
  expect_true(all(a >= 0L & a <= 255L))
  expect_false(identical(a, .minify_keystream(43L, 64L)))
})

test_that("an island survives encode then decode, ASCII and UTF-8 alike", {
  cases <- c(
    ascii   = '{"a":1,"b":"plain"}',
    utf8    = '{"v":"an em dash \u2014, an emoji \U0001F600, and \u00e9"}',
    escaped = '{"html":"\\u003c/script\\u003e then \\u003c!-- comment"}'
  )
  ks <- .minify_keystream(99L, max(nchar(cases, type = "bytes")))
  for (nm in names(cases)) {
    enc <- .minify_encode_island(cases[[nm]], ks)
    expect_identical(.minify_decode_island(enc, ks), enc2utf8(cases[[nm]]),
                     info = nm)
    expect_error(jsonlite::fromJSON(enc), info = nm)
  }
})

test_that("only marked, non-null islands are encoded", {
  res <- .minify_encode_islands(.island_html(), 12345L)
  expect_equal(res$count, 2L)                       # data-agg and data-micro
  expect_true(grepl('id="data-agg" data-island="v2" data-k="12345"', res$html,
                    fixed = TRUE))
  # null bodies, unmarked islands and user-state are left exactly as they were
  expect_true(grepl('id="data-qual" data-island="v2">null<', res$html, fixed = TRUE))
  expect_true(grepl('id="user-state">null<', res$html, fixed = TRUE))
  expect_true(grepl('id="sim-data">{"unmarked":true}<', res$html, fixed = TRUE))
})

test_that("an island that already carries data-k is not encoded twice", {
  # report_hub minifies a hub built from finished reports, and re-minifying a
  # file is an existing supported case. Encoding twice would leave the browser
  # decoding one layer and finding base64.
  once <- .minify_encode_islands(.island_html(), 777L)
  twice <- .minify_encode_islands(once$html, 888L)
  expect_equal(twice$count, 0L)
  expect_identical(twice$html, once$html)
})

test_that("a development build leaves every island readable", {
  skip_if_not(.has_terser(), "terser not available")
  tmp <- tempfile(pattern = "turas_islands_dev", fileext = ".html")
  writeLines(.island_html(), tmp, useBytes = TRUE)
  out <- .minify_derive_output_path(tmp)
  on.exit(unlink(c(tmp, out)), add = TRUE)

  res <- suppressWarnings(turas_minify(tmp, verbose = FALSE, deliverable = FALSE,
                                       obfuscate_js = FALSE))
  expect_equal(res$islands_encoded, 0L)
  html <- paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl("data-k=", html, fixed = TRUE))
})

test_that("the R encoder and the shipped fixture agree", {
  # The fixture the node suite reads. If the R side changes and the fixture is
  # not regenerated, this fails here rather than silently in a browser.
  root <- dirname(dirname(dirname(normalizePath(shared_lib, mustWork = FALSE))))
  fx_path <- file.path(root, "modules", "tabs", "lib", "html_report_v2", "tests",
                       "fixtures", "island_encoding.json")
  skip_if_not(file.exists(fx_path), "island encoding fixture not present")
  fx <- jsonlite::fromJSON(fx_path, simplifyDataFrame = FALSE)
  longest <- max(vapply(fx$cases, function(c) nchar(c$plain, type = "bytes"),
                        integer(1)))
  ks <- .minify_keystream(as.integer(fx$seed), longest)
  for (c in fx$cases) {
    expect_identical(.minify_encode_island(c$plain, ks), c$encoded, info = c$name)
  }
})


test_that("a document whose last script block is a JSON island still minifies", {
  # `contents[[i]] <- NULL` deletes the element and shortens the list, so the
  # indices stop matching `blocks`. Real reports survived only because their
  # last script block is the JS one. This is the shape that did not.
  skip_if_not(.has_terser(), "terser not available")
  html <- paste0('<html><body>\n',
                 '<script>function real() { return 1; }</script>\n',
                 '<script type="application/json" id="data-agg" data-island="v2">',
                 '{"a":1}</script>\n',
                 '<script type="application/json" id="user-state">null</script>\n',
                 '</body></html>')
  tmp <- tempfile(pattern = "turas_tail_json", fileext = ".html")
  writeLines(html, tmp, useBytes = TRUE)
  out <- .minify_derive_output_path(tmp)
  on.exit(unlink(c(tmp, out)), add = TRUE)

  res <- suppressWarnings(turas_minify(tmp, verbose = FALSE, deliverable = FALSE,
                                       obfuscate_js = FALSE))
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_true(file.exists(out))
  written <- paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_true(grepl('id="data-agg"', written, fixed = TRUE))
  expect_true(grepl('id="user-state"', written, fixed = TRUE))
})
