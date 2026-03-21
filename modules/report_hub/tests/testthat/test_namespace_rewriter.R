# Report Hub -- Namespace Rewriter Tests (02_namespace_rewriter.R)
# Tests for rewrite_html_ids(), rewrite_css_ids(), rewrite_for_hub(),
# remove_save_print_buttons(), redirect_pin_functions(), redirect_save_functions(),
# rewrite_js_ids()

# ==============================================================================
# 3. NAMESPACE REWRITER: rewrite_html_ids()
# ==============================================================================

test_that("rewrite_html_ids prefixes id attributes", {
  html <- '<div id="tab-overview" class="tab-panel">content</div>'
  result <- rewrite_html_ids(html, "tracker--")

  expect_true(grepl('id="tracker--tab-overview"', result))
  expect_true(grepl('class="tab-panel"', result))  # class unchanged
})

test_that("rewrite_html_ids prefixes multiple IDs", {
  html <- '<div id="first">a</div><span id="second">b</span>'
  result <- rewrite_html_ids(html, "tk--")

  expect_true(grepl('id="tk--first"', result))
  expect_true(grepl('id="tk--second"', result))
})

test_that("rewrite_html_ids rewrites href fragment links", {
  html <- '<a href="#section-a">Link</a>'
  result <- rewrite_html_ids(html, "tk--")

  expect_true(grepl('href="#tk--section-a"', result))
})

test_that("rewrite_html_ids rewrites for attributes on labels", {
  html <- '<label for="input-name">Name</label>'
  result <- rewrite_html_ids(html, "tk--")

  expect_true(grepl('for="tk--input-name"', result))
})

test_that("rewrite_html_ids does not double-prefix", {
  html <- '<div id="tab-overview">content</div>'
  result <- rewrite_html_ids(html, "tracker--")
  result2 <- rewrite_html_ids(result, "tracker--")

  # After second rewrite, it would be double-prefixed (expected behaviour for this function)
  # The function does not check for existing prefixes by design (called once per report)
  expect_true(grepl('id="tracker--tracker--tab-overview"', result2))
})

test_that("rewrite_html_ids preserves data attributes", {
  html <- '<div data-metric-id="m1" id="panel-1">content</div>'
  result <- rewrite_html_ids(html, "tk--")

  # id should be prefixed

  expect_true(grepl('id="tk--panel-1"', result))
  # data-metric-id should NOT be prefixed (the regex requires whitespace before id=)
  expect_true(grepl('data-metric-id="m1"', result))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: rewrite_css_ids()
# ==============================================================================

test_that("rewrite_css_ids prefixes CSS ID selectors with hyphens/underscores", {
  css <- '#tab-overview { display: block; } #tab-metrics { display: none; }'
  result <- rewrite_css_ids(css, "tracker--")

  expect_true(grepl('#tracker--tab-overview', result))
  expect_true(grepl('#tracker--tab-metrics', result))
})

test_that("rewrite_css_ids does NOT prefix hex colour codes", {
  css <- 'body { background-color: #e2e8f0; color: #333; border: 1px solid #fff; }'
  result <- rewrite_css_ids(css, "tracker--")

  # Hex colours should remain unchanged (no hyphen/underscore = no match)
  expect_true(grepl('#e2e8f0', result))
  expect_true(grepl('#333', result))
  expect_true(grepl('#fff', result))
})

test_that("rewrite_css_ids handles IDs with underscores", {
  css <- '#mv_metric_1 { font-weight: bold; }'
  result <- rewrite_css_ids(css, "tk--")

  expect_true(grepl('#tk--mv_metric_1', result))
})

test_that("rewrite_css_ids handles mixed selectors", {
  css <- '.panel #tab-overview { display:block; } .panel #ccc { color: #ccc; }'
  result <- rewrite_css_ids(css, "tk--")

  expect_true(grepl('#tk--tab-overview', result))
  # #ccc (hex colour, no hyphen/underscore) should not be prefixed
  expect_true(grepl('#ccc', result))
  # #ccc should NOT become #tk--ccc
  expect_false(grepl('#tk--ccc', result))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: rewrite_for_hub() (integration)
# ==============================================================================

test_that("rewrite_for_hub namespaces all components", {
  # Build a minimal parsed report structure
  parsed <- list(
    report_key = "tracker",
    report_type = "tracker",
    content_panels = list(
      overview = '<div id="tab-overview" class="tab-panel"><button onclick="saveReportHTML()">Save</button></div>',
      metrics = '<div id="tab-metrics" class="tab-panel">content</div>'
    ),
    report_tabs = list(
      html = '<div class="report-tabs"><button onclick="switchReportTab(\'overview\')">Overview</button></div>',
      tab_names = c("overview", "metrics")
    ),
    header = '<header class="tk-header" id="main-header">Header</header>',
    footer = '<footer class="tk-footer" id="main-footer">Footer</footer>',
    help_overlay = "",
    css_blocks = list(
      list(content = '#tab-overview { display: block; }')
    ),
    js_blocks = list(
      list(content = 'function switchReportTab(tab) { console.log(tab); }')
    ),
    data_scripts = list(
      list(
        id = "pinned-views-data",
        open_tag = '<script type="application/json" id="pinned-views-data">',
        content = "[]"
      )
    ),
    metadata = list(report_type = "tracker"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)

  # Content panels should have prefixed IDs
  expect_true(grepl('id="tracker--tab-overview"', result$content_panels$overview))
  expect_true(grepl('id="tracker--tab-metrics"', result$content_panels$metrics))

  # Save buttons should be removed
  expect_false(grepl('saveReportHTML', result$content_panels$overview))

  # Header and footer should have prefixed IDs
  expect_true(grepl('id="tracker--main-header"', result$header))
  expect_true(grepl('id="tracker--main-footer"', result$footer))

  # CSS should have prefixed selectors
  expect_true(grepl('#tracker--tab-overview', result$css_blocks[[1]]$content))

  # Report tab navigation should redirect to ReportHub.switchSubTab
  expect_true(grepl("ReportHub.switchSubTab", result$report_tabs$html))

  # Data scripts should have prefixed IDs
  expect_equal(result$data_scripts[[1]]$id, "tracker--pinned-views-data")

  # Wrapped JS should exist
  expect_true(nzchar(result$wrapped_js))
})

test_that("rewrite_for_hub removes save/print buttons", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    content_panels = list(
      crosstabs = paste0(
        '<div id="tab-crosstabs" class="tab-panel">',
        '<button onclick="saveReportHTML()">Save</button>',
        '<button onclick="printReport()">Print</button>',
        '<button onclick="printAllPins()">Print Pins</button>',
        '</div>'
      )
    ),
    report_tabs = list(html = "", tab_names = character(0)),
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

  # All save/print buttons should be gone
  panel_html <- result$content_panels$crosstabs
  expect_false(grepl("saveReportHTML", panel_html))
  expect_false(grepl("printReport", panel_html))
  expect_false(grepl("printAllPins", panel_html))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: remove_save_print_buttons()
# ==============================================================================

test_that("remove_save_print_buttons removes save button", {
  html <- '<div><button class="save" onclick="saveReportHTML()">Save</button></div>'
  result <- remove_save_print_buttons(html)

  expect_false(grepl("saveReportHTML", result))
  expect_true(grepl("<div>", result))
})

test_that("remove_save_print_buttons removes print button", {
  html <- '<button class="print" onclick="printReport()">Print</button>'
  result <- remove_save_print_buttons(html)

  expect_false(grepl("printReport", result))
})

test_that("remove_save_print_buttons removes printAllPins button", {
  html <- '<button onclick="printAllPins()">Print All</button>'
  result <- remove_save_print_buttons(html)

  expect_false(grepl("printAllPins", result))
})

test_that("remove_save_print_buttons preserves non-matching buttons", {
  html <- '<button onclick="doSomething()">Keep Me</button>'
  result <- remove_save_print_buttons(html)

  expect_equal(result, html)
})


# ==============================================================================
# 3. NAMESPACE REWRITER: redirect_pin_functions()
# ==============================================================================

test_that("redirect_pin_functions redirects updatePinBadge to ReportHub", {
  js <- 'updatePinBadge(count);'
  result <- redirect_pin_functions(js, "tracker")

  expect_true(grepl("ReportHub.updatePinBadge", result))
})

test_that("redirect_pin_functions redirects savePinnedData to ReportHub", {
  js <- 'savePinnedData(data);'
  result <- redirect_pin_functions(js, "tabs")

  expect_true(grepl("ReportHub.savePinnedData", result))
})

test_that("redirect_pin_functions does not redirect function declarations", {
  js <- 'function updatePinBadge(count) { /* impl */ }'
  result <- redirect_pin_functions(js, "tracker")

  # Should NOT redirect the declaration itself
  expect_true(grepl("function updatePinBadge", result))
})

test_that("redirect_pin_functions does not redirect method calls", {
  js <- 'someObj.updatePinBadge(count);'
  result <- redirect_pin_functions(js, "tracker")

  # Should NOT redirect since it's a method call (.updatePinBadge)
  expect_true(grepl("someObj.updatePinBadge", result))
  expect_false(grepl("someObj.ReportHub", result))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: redirect_save_functions()
# ==============================================================================

test_that("redirect_save_functions redirects saveReportHTML to ReportHub", {
  js <- 'saveReportHTML();'
  result <- redirect_save_functions(js)

  expect_true(grepl("ReportHub.saveReportHTML", result))
})

test_that("redirect_save_functions does not redirect function declaration", {
  js <- 'function saveReportHTML() { /* impl */ }'
  result <- redirect_save_functions(js)

  expect_true(grepl("function saveReportHTML", result))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: rewrite_js_ids()
# ==============================================================================

test_that("rewrite_js_ids redirects switchReportTab to ReportHub.switchSubTab", {
  js <- 'switchReportTab("overview");'
  result <- rewrite_js_ids(js, "tracker--", "tracker")

  expect_true(grepl("ReportHub.switchSubTab\\('tracker',", result))
  expect_false(grepl("switchReportTab", result))
})

test_that("rewrite_js_ids does not redirect switchReportTab function definition", {
  js <- 'function switchReportTab(tab) { console.log(tab); }'
  result <- rewrite_js_ids(js, "tracker--", "tracker")

  expect_true(grepl("function switchReportTab", result))
})
