# ==============================================================================
# TESTS: HTML REPORT (lib/html_report/) — v3.1 Comprehensive
# ==============================================================================

# Locate module root — works from project root or test directory
.find_conjoint_root <- function() {
  # Try the test file path itself (absolute when run via test_file())
  tf <- tryCatch(testthat::test_path(".."), error = function(e) NULL)

  candidates <- c(
    # Absolute path from test_file() — test_path("..") gives tests/ dir
    if (!is.null(tf)) normalizePath(file.path(tf, ".."), mustWork = FALSE) else NULL,
    # cwd-based (when run from project root)
    file.path(getwd(), "modules", "conjoint"),
    # Fallback: relative test_path navigation
    normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = FALSE)
  )

  for (p in candidates) {
    if (is.null(p)) next
    check <- file.path(p, "lib", "html_report", "00_html_guard.R")
    if (file.exists(check)) return(p)
  }
  NULL
}

conjoint_root <- .find_conjoint_root()

if (!is.null(conjoint_root)) {
  # Null coalesce operator
  if (!exists("%||%", mode = "function")) {
    `%||%` <- function(x, y) if (is.null(x)) y else x
  }

  # Set lib dir global for page builder JS loading
  assign(".conjoint_lib_dir", file.path(conjoint_root, "lib"), envir = globalenv())

  # Load fixture data generators into global env
  fixture_path <- file.path(conjoint_root, "tests", "fixtures", "synthetic_data",
                            "generate_conjoint_test_data.R")
  if (file.exists(fixture_path)) source(fixture_path, local = FALSE)

  # Pre-load HTML report submodules
  html_report_dir <- file.path(conjoint_root, "lib", "html_report")
  for (f in c("00_html_guard.R", "01_data_transformer.R", "02_table_builder.R",
              "05_chart_builder.R", "03_page_builder.R", "04_html_writer.R")) {
    fpath <- file.path(html_report_dir, f)
    if (file.exists(fpath)) source(fpath, local = FALSE)
  }

  # Load report orchestrator (for generate_conjoint_html_report)
  main_path <- file.path(html_report_dir, "99_html_report_main.R")
  if (file.exists(main_path)) source(main_path, local = FALSE)

  # Load deprecated simulator wrapper
  sim_path <- file.path(conjoint_root, "lib", "html_simulator", "99_simulator_main.R")
  if (file.exists(sim_path)) source(sim_path, local = FALSE)
}


# ==============================================================================
# GUARD LAYER TESTS
# ==============================================================================

test_that("html guard validates conjoint_results structure", {
  if (!exists("validate_conjoint_html_inputs", mode = "function")) skip("validate_conjoint_html_inputs not loaded")

  # Valid input
  valid <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df()
  )
  result <- validate_conjoint_html_inputs(valid)
  expect_true(result$valid)

  # Invalid: not a list
  result2 <- validate_conjoint_html_inputs("not a list")
  expect_false(result2$valid)

  # Invalid: missing both utilities and importance
  result3 <- validate_conjoint_html_inputs(list(other = 1))
  expect_false(result3$valid)
})


test_that("html guard validates colour codes", {
  if (!exists("validate_conjoint_html_inputs", mode = "function")) skip("validate_conjoint_html_inputs not loaded")

  valid_input <- list(utilities = generate_utilities_df())

  # Valid colour
  result <- validate_conjoint_html_inputs(valid_input, list(brand_colour = "#1a2b3c"))
  expect_true(result$valid)

  # Invalid colour — named colour
  result2 <- validate_conjoint_html_inputs(valid_input, list(brand_colour = "red"))
  expect_false(result2$valid)

  # Invalid — 3-char hex
  result3 <- validate_conjoint_html_inputs(valid_input, list(brand_colour = "#abc"))
  expect_false(result3$valid)

  # Valid — accent colour
  result4 <- validate_conjoint_html_inputs(valid_input, list(accent_colour = "#FF9900"))
  expect_true(result4$valid)
})


test_that("html guard validates utilities data frame", {
  if (!exists("validate_conjoint_html_inputs", mode = "function")) skip("validate_conjoint_html_inputs not loaded")

  # Missing required columns
  bad_utils <- data.frame(x = 1, y = 2, z = 3)
  result <- validate_conjoint_html_inputs(list(utilities = bad_utils, importance = generate_importance_df()))
  expect_false(result$valid)
  expect_true(any(grepl("missing columns", result$errors)))

  # Empty data frame
  empty_utils <- generate_utilities_df()[0, ]
  result2 <- validate_conjoint_html_inputs(list(utilities = empty_utils, importance = generate_importance_df()))
  expect_false(result2$valid)
  expect_true(any(grepl("no rows", result2$errors)))
})


test_that("html guard validates WTP data with warnings", {
  if (!exists("validate_conjoint_html_inputs", mode = "function")) skip("validate_conjoint_html_inputs not loaded")

  # WTP with missing columns produces warnings, not errors
  input_with_bad_wtp <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    wtp = list(wtp_table = data.frame(foo = 1))
  )
  result <- validate_conjoint_html_inputs(input_with_bad_wtp)
  expect_true(result$valid)  # warnings, not errors
  expect_true(any(grepl("WTP table missing columns", result$warnings)))
})


test_that("html guard validates insight config", {
  if (!exists("validate_conjoint_html_inputs", mode = "function")) skip("validate_conjoint_html_inputs not loaded")

  input <- list(utilities = generate_utilities_df())

  # Valid insight strings
  cfg <- list(insight_overview = "Some insight", insight_utilities = "Another")
  result <- validate_conjoint_html_inputs(input, cfg)
  expect_true(result$valid)

  # Non-character insight produces warning
  cfg2 <- list(insight_overview = 123)
  result2 <- validate_conjoint_html_inputs(input, cfg2)
  expect_true(result2$valid)  # warning, not error
  expect_true(any(grepl("insight_overview must be character", result2$warnings)))
})


# ==============================================================================
# DATA TRANSFORMER TESTS
# ==============================================================================

test_that("transformer builds complete data structure", {
  if (!exists("transform_conjoint_for_html", mode = "function")) skip("transform_conjoint_for_html not loaded")

  utils <- generate_utilities_df()
  importance <- generate_importance_df()

  conjoint_results <- list(
    utilities = utils,
    importance = importance,
    model_result = list(
      method = "mlogit",
      n_respondents = 100,
      n_choice_sets = 800,
      convergence = list(converged = TRUE)
    ),
    diagnostics = list(mcfadden_r2 = 0.35),
    config = list(project_name = "Test Project")
  )

  result <- transform_conjoint_for_html(conjoint_results, list())

  expect_is(result, "list")
  expect_true("summary" %in% names(result))
  expect_true("utilities" %in% names(result))
  expect_true("utilities_by_attr" %in% names(result))
  expect_true("importance" %in% names(result))
  expect_true("sidebar_nav" %in% names(result))
  expect_true("simulator_data" %in% names(result))
  expect_true("insights" %in% names(result))
  expect_true("about" %in% names(result))

  # Summary fields
  expect_equal(result$summary$estimation_method, "mlogit")
  expect_equal(result$summary$n_respondents, 100)
  expect_true(result$summary$converged)

  # Utilities split correctly
  expect_equal(length(result$utilities_by_attr), length(unique(utils$Attribute)))

  # Sidebar nav
  expect_equal(length(result$sidebar_nav), length(unique(utils$Attribute)))
  expect_true(result$sidebar_nav[[1]]$active)
})


test_that("transformer extracts WTP data when present", {
  if (!exists("transform_conjoint_for_html", mode = "function")) skip("transform_conjoint_for_html not loaded")

  wtp_table <- data.frame(
    Attribute = c("Brand", "Brand", "Size", "Size"),
    Level = c("Alpha", "Beta", "Small", "Large"),
    WTP = c(0, 15.5, 0, 8.2),
    is_baseline = c(TRUE, FALSE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit"),
    wtp = list(wtp_table = wtp_table, price_coefficient = -0.05, price_attribute = "Price")
  )

  result <- transform_conjoint_for_html(conjoint_results, list())

  expect_false(is.null(result$wtp_data))
  expect_equal(nrow(result$wtp_data$wtp_table), 4)
  expect_equal(result$wtp_data$price_coefficient, -0.05)
})


test_that("transformer extracts insight seeds from config", {
  if (!exists("transform_conjoint_for_html", mode = "function")) skip("transform_conjoint_for_html not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit")
  )

  config <- list(
    insight_overview = "Brand is key driver",
    insight_utilities = "Price sensitivity is high",
    insight_diagnostics = ""  # empty, should be excluded
  )

  result <- transform_conjoint_for_html(conjoint_results, config)

  expect_true("overview" %in% names(result$insights))
  expect_true("utilities" %in% names(result$insights))
  expect_false("diagnostics" %in% names(result$insights))  # empty excluded
  expect_equal(result$insights$overview, "Brand is key driver")
})


test_that("transformer extracts about page data", {
  if (!exists("transform_conjoint_for_html", mode = "function")) skip("transform_conjoint_for_html not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    model_result = list(method = "mlogit")
  )

  config <- list(
    analyst_name = "Jane Doe",
    analyst_email = "jane@example.com",
    company_name = "Test Corp"
  )

  result <- transform_conjoint_for_html(conjoint_results, config)

  expect_true(result$about$has_content)
  expect_equal(result$about$analyst_name, "Jane Doe")
  expect_equal(result$about$company_name, "Test Corp")
})


test_that("simulator_data_to_json produces valid JSON", {
  if (!exists("simulator_data_to_json", mode = "function")) skip("simulator_data_to_json not loaded")

  # NULL returns empty JSON
  expect_equal(simulator_data_to_json(NULL), "{}")

  # Valid data
  sim_data <- list(
    meta = list(project_name = "Test", estimation_method = "mlogit"),
    attributes = list(
      list(name = "Brand", levels = list(list(name = "A", utility = 0)))
    )
  )
  json_str <- simulator_data_to_json(sim_data)
  expect_true(is.character(json_str))
  expect_true(grepl("Test", json_str))
  expect_true(grepl("Brand", json_str))

  # Should be parseable JSON
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    parsed <- jsonlite::fromJSON(json_str)
    expect_equal(parsed$meta$project_name, "Test")
  }
})


# ==============================================================================
# TABLE BUILDER TESTS
# ==============================================================================

test_that("importance table has export attributes", {
  if (!exists("build_importance_table", mode = "function")) skip("build_importance_table not loaded")

  imp <- generate_importance_df()
  html <- build_importance_table(imp)

  expect_true(is.character(html))
  expect_true(nzchar(html))
  expect_true(grepl("data-table-id", html))
  expect_true(grepl("data-col-key", html))
  expect_true(grepl("data-export-value", html))
  # Should contain all attributes
  for (attr in imp$Attribute) {
    expect_true(grepl(attr, html, fixed = TRUE))
  }
})


test_that("utility table renders per-attribute levels", {
  if (!exists("build_utilities_table", mode = "function")) skip("build_utilities_table not loaded")

  utils <- generate_utilities_df()
  brand_utils <- utils[utils$Attribute == "Brand", ]
  html <- build_utilities_table(brand_utils)

  expect_true(grepl("Alpha", html, fixed = TRUE))
  expect_true(grepl("Beta", html, fixed = TRUE))
  expect_true(grepl("Gamma", html, fixed = TRUE))
  expect_true(grepl("data-col-key", html))
})


test_that("WTP table renders when data provided", {
  if (!exists("build_wtp_table", mode = "function")) skip("build_wtp_table not loaded")

  wtp_data <- list(
    wtp_table = data.frame(
      Attribute = c("Brand", "Brand"),
      Level = c("Alpha", "Beta"),
      WTP = c(0, 15.5),
      is_baseline = c(TRUE, FALSE),
      stringsAsFactors = FALSE
    ),
    price_coefficient = -0.05,
    price_attribute = "Price"
  )

  html <- build_wtp_table(wtp_data)

  expect_true(is.character(html))
  expect_true(grepl("data-table-id", html))
  expect_true(grepl("Beta", html, fixed = TRUE))
})


test_that("model fit table handles NULL diagnostics gracefully", {
  if (!exists("build_model_fit_table", mode = "function")) skip("build_model_fit_table not loaded")

  html <- build_model_fit_table(NULL, NULL)
  expect_true(is.character(html))
  expect_true(nzchar(html))
})


# ==============================================================================
# CHART BUILDER TESTS
# ==============================================================================

test_that("importance chart produces valid SVG", {
  if (!exists("build_importance_chart", mode = "function")) skip("build_importance_chart not loaded")

  imp <- generate_importance_df()
  svg <- build_importance_chart(imp, "#1e40af")

  expect_true(is.character(svg))
  expect_true(grepl("<svg", svg))
  expect_true(grepl("data-chart-id", svg))
  expect_true(grepl("</svg>", svg))
  # Should reference attributes
  for (attr in imp$Attribute) {
    expect_true(grepl(attr, svg, fixed = TRUE))
  }
})


test_that("utility chart produces valid SVG", {
  if (!exists("build_utility_chart", mode = "function")) skip("build_utility_chart not loaded")

  utils <- generate_utilities_df()
  brand_utils <- utils[utils$Attribute == "Brand", ]
  svg <- build_utility_chart(brand_utils, "Brand", "#1e40af")

  expect_true(grepl("<svg", svg))
  expect_true(grepl("data-chart-id", svg))
  expect_true(grepl("Alpha", svg, fixed = TRUE))
})


test_that("WTP chart renders with data", {
  if (!exists("build_wtp_chart", mode = "function")) skip("build_wtp_chart not loaded")

  wtp_data <- list(
    wtp_table = data.frame(
      Attribute = c("Brand", "Brand", "Size", "Size"),
      Level = c("Alpha", "Beta", "Small", "Large"),
      WTP = c(0, 15.5, 0, 8.2),
      is_baseline = c(TRUE, FALSE, TRUE, FALSE),
      stringsAsFactors = FALSE
    )
  )

  svg <- build_wtp_chart(wtp_data, "#1e40af")
  expect_true(grepl("<svg", svg))
  expect_true(grepl("data-chart-id", svg))
})


# ==============================================================================
# PAGE BUILDER TESTS
# ==============================================================================

test_that("page builder produces complete HTML document", {
  if (!exists("build_conjoint_page", mode = "function")) skip("build_conjoint_page not loaded")
  if (!exists("transform_conjoint_for_html", mode = "function")) skip("transform_conjoint_for_html not loaded")

  utils <- generate_utilities_df()
  imp <- generate_importance_df()

  conjoint_results <- list(
    utilities = utils,
    importance = imp,
    model_result = list(
      method = "mlogit",
      n_respondents = 100,
      n_choice_sets = 800,
      convergence = list(converged = TRUE)
    ),
    diagnostics = list(mcfadden_r2 = 0.35)
  )

  config <- list(
    project_name = "Test Report",
    brand_colour = "#2563eb",
    accent_colour = "#f59e0b"
  )

  html_data <- transform_conjoint_for_html(conjoint_results, config)
  brand <- config$brand_colour

  # Build minimal tables and charts
  tables <- list(
    importance = if (exists("build_importance_table", mode = "function"))
      build_importance_table(imp) else "<table></table>",
    model_fit = if (exists("build_model_fit_table", mode = "function"))
      build_model_fit_table(NULL, NULL) else "<table></table>",
    utility_tables = list()
  )

  charts <- list(
    importance = if (exists("build_importance_chart", mode = "function"))
      build_importance_chart(imp, brand) else "<svg></svg>",
    utility_charts = list()
  )

  page <- build_conjoint_page(html_data, tables, charts, config)

  expect_true(is.character(page))
  expect_true(grepl("<!DOCTYPE html>", page, fixed = TRUE))
  expect_true(grepl("</html>", page, fixed = TRUE))
})


test_that("page builder includes all required panels", {
  if (!exists("build_conjoint_page", mode = "function")) skip("build_conjoint_page not loaded")
  if (!exists("transform_conjoint_for_html", mode = "function")) skip("transform_conjoint_for_html not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit", n_respondents = 100)
  )
  config <- list(brand_colour = "#2563eb")

  html_data <- transform_conjoint_for_html(conjoint_results, config)

  tables <- list(
    importance = "<table data-table-id='imp'></table>",
    model_fit = "<table></table>",
    utility_tables = list()
  )
  charts <- list(
    importance = "<svg></svg>",
    utility_charts = list()
  )

  page <- build_conjoint_page(html_data, tables, charts, config)

  # Required panels
  expect_true(grepl("panel-overview", page, fixed = TRUE))
  expect_true(grepl("panel-utilities", page, fixed = TRUE))
  expect_true(grepl("panel-diagnostics", page, fixed = TRUE))
  expect_true(grepl("panel-simulator", page, fixed = TRUE))
  expect_true(grepl("panel-pinned", page, fixed = TRUE))

  # Tab navigation
  expect_true(grepl("cj-report-tabs", page, fixed = TRUE))

  # Header
  expect_true(grepl("cj-header", page, fixed = TRUE))
})


test_that("page builder includes help overlay", {
  if (!exists("build_help_overlay", mode = "function")) skip("build_help_overlay not loaded")

  help_html <- build_help_overlay()
  expect_true(grepl("cj-help-overlay", help_html, fixed = TRUE))
  expect_true(grepl("Quick Guide", help_html, fixed = TRUE))
})


test_that("page builder includes print CSS", {
  if (!exists("build_conjoint_print_css", mode = "function")) skip("build_conjoint_print_css not loaded")

  css <- build_conjoint_print_css()
  expect_true(grepl("@media print", css, fixed = TRUE))
  expect_true(grepl("landscape", css))
})


test_that("page builder includes insight areas with seed text", {
  if (!exists("build_insight_area", mode = "function")) skip("build_insight_area not loaded")

  insights <- list(overview = "Brand is dominant")
  html <- build_insight_area("overview", insights)

  expect_true(grepl("cj-insight-area", html, fixed = TRUE))
  expect_true(grepl("contenteditable", html, fixed = TRUE))
  expect_true(grepl("Brand is dominant", html, fixed = TRUE))
})


test_that("page builder export bar has all buttons", {
  if (!exists(".build_export_bar", mode = "function")) skip(".build_export_bar not loaded")

  bar <- .build_export_bar("overview")
  expect_true(grepl("exportCSV", bar, fixed = TRUE))
  expect_true(grepl("exportExcel", bar, fixed = TRUE))
  expect_true(grepl("exportChartPNG", bar, fixed = TRUE))
})


test_that("page builder includes simulator data JSON", {
  if (!exists("build_conjoint_page", mode = "function")) skip("build_conjoint_page not loaded")
  if (!exists("transform_conjoint_for_html", mode = "function")) skip("transform_conjoint_for_html not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit", n_respondents = 100)
  )
  config <- list(brand_colour = "#2563eb")

  html_data <- transform_conjoint_for_html(conjoint_results, config)

  tables <- list(importance = "<table></table>", model_fit = "<table></table>", utility_tables = list())
  charts <- list(importance = "<svg></svg>", utility_charts = list())

  page <- build_conjoint_page(html_data, tables, charts, config)

  # Simulator JSON data block
  expect_true(grepl("cj-simulator-data", page, fixed = TRUE))
  expect_true(grepl("application/json", page, fixed = TRUE))
})


test_that("page builder meta tags include source-filename", {
  if (!exists("build_conjoint_meta", mode = "function")) skip("build_conjoint_meta not loaded")

  summary <- list(
    project_name = "Test",
    generated = "2026-03-12 10:00:00",
    estimation_method = "mlogit",
    n_respondents = 100,
    n_attributes = 3
  )
  config <- list()

  meta <- build_conjoint_meta(summary, config)
  expect_true(grepl('turas-report-type.*conjoint', meta))
  expect_true(grepl("meta", meta))
})


# ==============================================================================
# JS FILE VALIDATION
# ==============================================================================

test_that("all 7 JS files have valid syntax", {
  js_dir <- if (!is.null(conjoint_root)) file.path(conjoint_root, "lib", "html_report", "js") else NULL

  if (is.null(js_dir) || !dir.exists(js_dir)) skip("JS directory not found")

  js_files <- list.files(js_dir, pattern = "\\.js$", full.names = TRUE)
  expect_gte(length(js_files), 7, label = "Expected at least 7 JS files")

  node_path <- "/usr/local/bin/node"
  if (!file.exists(node_path)) skip("node not found at /usr/local/bin/node")

  for (f in js_files) {
    result <- system2(node_path, args = c("--check", f), stdout = TRUE, stderr = TRUE)
    exit_code <- attr(result, "status") %||% 0L
    expect_equal(exit_code, 0L,
      info = sprintf("JS syntax error in %s: %s", basename(f), paste(result, collapse = "\n"))
    )
  }
})


test_that("JS files contain expected module patterns", {
  js_dir <- if (!is.null(conjoint_root)) file.path(conjoint_root, "lib", "html_report", "js") else NULL

  if (is.null(js_dir) || !dir.exists(js_dir)) skip("JS directory not found")

  # Navigation JS should have switchReportTab
  nav_file <- file.path(js_dir, "conjoint_navigation.js")
  if (file.exists(nav_file)) {
    nav_js <- paste(readLines(nav_file, warn = FALSE), collapse = "\n")
    expect_true(grepl("switchReportTab", nav_js, fixed = TRUE))
    expect_true(grepl("selectAttribute", nav_js, fixed = TRUE))
    expect_true(grepl("saveReportHTML", nav_js, fixed = TRUE))
  }

  # Export JS should have exportCSV
  export_file <- file.path(js_dir, "conjoint_export.js")
  if (file.exists(export_file)) {
    export_js <- paste(readLines(export_file, warn = FALSE), collapse = "\n")
    expect_true(grepl("exportCSV", export_js, fixed = TRUE))
    expect_true(grepl("exportExcel", export_js, fixed = TRUE))
    expect_true(grepl("exportChartPNG", export_js, fixed = TRUE))
  }

  # Pins JS should have togglePin
  pins_file <- file.path(js_dir, "conjoint_pins.js")
  if (file.exists(pins_file)) {
    pins_js <- paste(readLines(pins_file, warn = FALSE), collapse = "\n")
    expect_true(grepl("togglePin", pins_js, fixed = TRUE))
    expect_true(grepl("hydratePinnedViews", pins_js, fixed = TRUE))
  }

  # Simulator engine should have predictSharesLogit
  engine_file <- file.path(js_dir, "simulator_engine.js")
  if (file.exists(engine_file)) {
    engine_js <- paste(readLines(engine_file, warn = FALSE), collapse = "\n")
    expect_true(grepl("predictSharesLogit", engine_js, fixed = TRUE))
    expect_true(grepl("demandCurve", engine_js, fixed = TRUE))
  }
})


# ==============================================================================
# FULL PIPELINE (INTEGRATION) TEST
# ==============================================================================

test_that("html report generates valid HTML file with all panels", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(
      method = "mlogit",
      mcfadden_r2 = 0.35,
      aic = 1234,
      bic = 1280,
      n_obs = 600,
      n_respondents = 100,
      n_choice_sets = 800,
      convergence = list(converged = TRUE)
    ),
    diagnostics = list(mcfadden_r2 = 0.35, aic = 1234, bic = 1280)
  )

  config <- list(
    project_name = "Test Project",
    brand_colour = "#2563eb",
    accent_colour = "#f59e0b",
    insight_overview = "Test insight seed text",
    analyst_name = "Test Analyst"
  )

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, tmp_path, config)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp_path))

  # Read and validate HTML content
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")

  # Document structure
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl('turas-report-type.*conjoint', html))
  expect_true(grepl("</html>", html, fixed = TRUE))

  # All major panels
  expect_true(grepl("panel-overview", html, fixed = TRUE))
  expect_true(grepl("panel-utilities", html, fixed = TRUE))
  expect_true(grepl("panel-diagnostics", html, fixed = TRUE))
  expect_true(grepl("panel-simulator", html, fixed = TRUE))
  expect_true(grepl("panel-pinned", html, fixed = TRUE))

  # Header
  expect_true(grepl("cj-header", html, fixed = TRUE))
  expect_true(grepl("Test Project", html, fixed = TRUE))

  # Help overlay
  expect_true(grepl("cj-help-overlay", html, fixed = TRUE))

  # Print CSS
  expect_true(grepl("@media print", html, fixed = TRUE))

  # Simulator JSON
  expect_true(grepl("cj-simulator-data", html, fixed = TRUE))

  # Insight seed text
  expect_true(grepl("Test insight seed text", html, fixed = TRUE))

  # About page data
  expect_true(grepl("Test Analyst", html, fixed = TRUE))

  # Export buttons
  expect_true(grepl("exportCSV", html, fixed = TRUE))
})


test_that("html report handles WTP data in pipeline", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit", n_respondents = 50),
    wtp = list(
      wtp_table = data.frame(
        Attribute = c("Brand", "Brand"),
        Level = c("Alpha", "Beta"),
        WTP = c(0, 12.5),
        is_baseline = c(TRUE, FALSE),
        stringsAsFactors = FALSE
      ),
      price_coefficient = -0.04,
      price_attribute = "Price"
    )
  )

  config <- list(brand_colour = "#2563eb")

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, tmp_path, config)

  expect_equal(result$status, "PASS")
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")

  # WTP panel should appear
  expect_true(grepl("panel-wtp", html, fixed = TRUE))
})


test_that("html report rejects invalid inputs", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  # Invalid: not a list
  result <- generate_conjoint_html_report("bad", tmp_path)
  expect_equal(result$status, "REFUSED")

  # Invalid: bad colour
  result2 <- generate_conjoint_html_report(
    list(utilities = generate_utilities_df()),
    tmp_path,
    list(brand_colour = "notahex")
  )
  expect_equal(result2$status, "REFUSED")
})


# ==============================================================================
# DEPRECATED SIMULATOR WRAPPER
# ==============================================================================

test_that("deprecated simulator wrapper forwards to combined report", {
  if (!exists("generate_conjoint_html_simulator", mode = "function")) skip("generate_conjoint_html_simulator not loaded")
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  utils <- generate_utilities_df()
  imp <- generate_importance_df()
  config <- list(
    project_name = "Deprecated Test",
    brand_colour = "#2563eb",
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size = c("Small", "Medium", "Large"),
      Price = c("$10", "$20", "$30")
    )
  )

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  # Should produce a deprecation message and still generate output
  expect_message(
    result <- generate_conjoint_html_simulator(utils, imp, NULL, config, tmp_path),
    "DEPRECATED"
  )

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp_path))

  # Should be a combined report, not old simulator
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("panel-overview", html, fixed = TRUE))
})


# ==============================================================================
# CALLOUT BOXES
# ==============================================================================

test_that("callout helper produces correct HTML structure", {
  if (!exists(".build_callout", mode = "function")) skip(".build_callout not loaded")

  html <- .build_callout("Test Title", "<p>Test body text</p>")
  expect_true(grepl("cj-callout", html, fixed = TRUE))
  expect_true(grepl("cj-callout-title", html, fixed = TRUE))
  expect_true(grepl("Test Title", html, fixed = TRUE))
  expect_true(grepl("Test body text", html, fixed = TRUE))
})


test_that("diagnostics callouts produce method-specific text", {
  if (!exists(".build_diagnostics_callouts", mode = "function")) skip(".build_diagnostics_callouts not loaded")

  # MNL / mlogit
  html_data_mnl <- list(
    summary = list(estimation_method = "mlogit"),
    diagnostics = list(mcfadden_r2 = 0.35)
  )
  callouts <- .build_diagnostics_callouts(html_data_mnl)
  combined <- paste(callouts, collapse = "\n")
  expect_true(grepl("cj-callout", combined, fixed = TRUE))
  expect_true(grepl("Model Fit Quality", combined, fixed = TRUE))
  expect_true(grepl("Estimation Method", combined, fixed = TRUE))
  expect_true(grepl("Multinomial Logit", combined, fixed = TRUE))

  # HB
  html_data_hb <- list(
    summary = list(estimation_method = "hb"),
    diagnostics = list()
  )
  callouts_hb <- .build_diagnostics_callouts(html_data_hb)
  combined_hb <- paste(callouts_hb, collapse = "\n")
  expect_true(grepl("Hierarchical Bayes", combined_hb, fixed = TRUE))

  # Latent class
  html_data_lc <- list(
    summary = list(estimation_method = "latent_class"),
    diagnostics = list()
  )
  callouts_lc <- .build_diagnostics_callouts(html_data_lc)
  combined_lc <- paste(callouts_lc, collapse = "\n")
  expect_true(grepl("Latent Class", combined_lc, fixed = TRUE))
})


test_that("diagnostics callouts interpret McFadden R-squared ranges", {
  if (!exists(".build_diagnostics_callouts", mode = "function")) skip(".build_diagnostics_callouts not loaded")

  # Good fit (0.2-0.4)
  html_data <- list(
    summary = list(estimation_method = "mlogit"),
    diagnostics = list(fit_statistics = list(mcfadden_r2 = 0.32))
  )
  callouts <- paste(.build_diagnostics_callouts(html_data), collapse = "\n")
  expect_true(grepl("0.320", callouts, fixed = TRUE))

  # Excellent fit (>0.4)
  html_data2 <- list(
    summary = list(estimation_method = "mlogit"),
    diagnostics = list(fit_statistics = list(mcfadden_r2 = 0.55))
  )
  callouts2 <- paste(.build_diagnostics_callouts(html_data2), collapse = "\n")
  expect_true(grepl("0.550", callouts2, fixed = TRUE))
})


test_that("generated HTML includes callout boxes on major panels", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(
      method = "mlogit",
      n_respondents = 100,
      convergence = list(converged = TRUE)
    ),
    diagnostics = list(mcfadden_r2 = 0.35)
  )
  config <- list(brand_colour = "#2563eb")

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, tmp_path, config)
  expect_equal(result$status, "PASS")

  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")

  # Callout CSS class
  expect_true(grepl("cj-callout", html, fixed = TRUE))

  # Overview callout
  expect_true(grepl("What Is Attribute Importance", html, fixed = TRUE))

  # Utilities callout
  expect_true(grepl("Reading Utility Values", html, fixed = TRUE))

  # Diagnostics callouts
  expect_true(grepl("Model Fit Quality", html, fixed = TRUE))
  expect_true(grepl("Estimation Method", html, fixed = TRUE))

  # Simulator callouts (3 mode-switched)
  expect_true(grepl("cj-sim-callout-shares", html, fixed = TRUE))
  expect_true(grepl("cj-sim-callout-sensitivity", html, fixed = TRUE))
  expect_true(grepl("cj-sim-callout-sov", html, fixed = TRUE))

  # Simulator callout toggle CSS
  expect_true(grepl("cj-sim-callout", html, fixed = TRUE))
})


test_that("WTP callout appears when WTP data is present", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit", n_respondents = 50),
    wtp = list(
      wtp_table = data.frame(
        Attribute = c("Brand", "Brand"),
        Level = c("Alpha", "Beta"),
        WTP = c(0, 12.5),
        is_baseline = c(TRUE, FALSE),
        stringsAsFactors = FALSE
      ),
      price_coefficient = -0.04,
      price_attribute = "Price"
    )
  )
  config <- list(brand_colour = "#2563eb")

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, tmp_path, config)
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("Willingness to Pay", html, fixed = TRUE))
})


# ==============================================================================
# PIN BUTTONS (EMOJI) ON ALL VIEWS
# ==============================================================================

test_that("pin buttons use emoji character on all panels", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(
      method = "mlogit",
      n_respondents = 100,
      convergence = list(converged = TRUE)
    ),
    diagnostics = list(mcfadden_r2 = 0.35)
  )
  config <- list(brand_colour = "#2563eb")

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, tmp_path, config)
  expect_equal(result$status, "PASS")

  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")

  # Pin button CSS class
  expect_true(grepl("cj-pin-btn", html, fixed = TRUE))

  # Pin buttons should use SVG pin icon (replaced emoji for cross-platform rendering)
  expect_true(grepl("cj-pin-btn", html, fixed = TRUE))
  expect_true(grepl("togglePin", html, fixed = TRUE))

  # Overview pin
  expect_true(grepl("pin-overview", html, fixed = TRUE))

  # Diagnostics pins
  expect_true(grepl("pin-diagnostics-fit", html, fixed = TRUE))

  # Simulator pin
  expect_true(grepl("pin-simulator", html, fixed = TRUE))
})


test_that("pin buttons present on WTP and LC panels when data available", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit", n_respondents = 50),
    wtp = list(
      wtp_table = data.frame(
        Attribute = c("Brand", "Brand"),
        Level = c("Alpha", "Beta"),
        WTP = c(0, 12.5),
        is_baseline = c(TRUE, FALSE),
        stringsAsFactors = FALSE
      ),
      price_coefficient = -0.04,
      price_attribute = "Price"
    )
  )
  config <- list(brand_colour = "#2563eb")

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, tmp_path, config)
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")

  # WTP pins
  expect_true(grepl("pin-wtp-main", html, fixed = TRUE))
})


# ==============================================================================
# SLIDES PANEL
# ==============================================================================

test_that("slides panel is built and included in page", {
  if (!exists("build_slides_panel", mode = "function")) skip("build_slides_panel not loaded")

  slides_html <- build_slides_panel()
  expect_true(grepl("panel-slides", slides_html, fixed = TRUE))
  expect_true(grepl("cj-slides-container", slides_html, fixed = TRUE))
  expect_true(grepl("cj-slides-cards", slides_html, fixed = TRUE))
  expect_true(grepl("cj-slides-empty", slides_html, fixed = TRUE))
  expect_true(grepl("addSlide", slides_html, fixed = TRUE))
  expect_true(grepl("exportAllSlidesPNG", slides_html, fixed = TRUE))
  expect_true(grepl("printSlides", slides_html, fixed = TRUE))
})


test_that("slides panel appears in full HTML report", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit", n_respondents = 100)
  )
  config <- list(brand_colour = "#2563eb")

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, tmp_path, config)
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")

  # Slides panel present
  expect_true(grepl("panel-slides", html, fixed = TRUE))

  # Slides JSON data store for persistence
  expect_true(grepl("slides-data", html, fixed = TRUE))

  # Slides tab in navigation
  expect_true(grepl('data-tab="slides"', html, fixed = TRUE))
})


# ==============================================================================
# SIMULATOR EXPORT BAR
# ==============================================================================

test_that("simulator panel includes export bar with CSV and Excel", {
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  conjoint_results <- list(
    utilities = generate_utilities_df(),
    importance = generate_importance_df(),
    model_result = list(method = "mlogit", n_respondents = 100)
  )
  config <- list(brand_colour = "#2563eb")

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  result <- generate_conjoint_html_report(conjoint_results, tmp_path, config)
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")

  # Simulator-specific export functions
  expect_true(grepl("exportSimulatorCSV", html, fixed = TRUE))
  expect_true(grepl("exportSimulatorExcel", html, fixed = TRUE))
})


# ==============================================================================
# JS FILE CONTENT TESTS — NEW FEATURES
# ==============================================================================

test_that("navigation JS includes slides system functions", {
  js_dir <- if (!is.null(conjoint_root)) file.path(conjoint_root, "lib", "html_report", "js") else NULL
  if (is.null(js_dir) || !dir.exists(js_dir)) skip("JS directory not found")

  nav_file <- file.path(js_dir, "conjoint_navigation.js")
  if (!file.exists(nav_file)) skip("conjoint_navigation.js not found")

  nav_js <- paste(readLines(nav_file, warn = FALSE), collapse = "\n")

  # Slides functions
  expect_true(grepl("addSlide", nav_js, fixed = TRUE))
  expect_true(grepl("removeSlide", nav_js, fixed = TRUE))
  expect_true(grepl("moveSlide", nav_js, fixed = TRUE))
  expect_true(grepl("renderSlides", nav_js, fixed = TRUE))
  expect_true(grepl("hydrateSlides", nav_js, fixed = TRUE))
  expect_true(grepl("saveSlides", nav_js, fixed = TRUE))
  expect_true(grepl("pinSlide", nav_js, fixed = TRUE))
  expect_true(grepl("exportAllSlidesPNG", nav_js, fixed = TRUE))

  # Callout toggle in switchSimMode
  expect_true(grepl("cj-sim-callout", nav_js, fixed = TRUE))
  expect_true(grepl("switchSimMode", nav_js, fixed = TRUE))
})


test_that("export JS includes simulator-specific export functions", {
  js_dir <- if (!is.null(conjoint_root)) file.path(conjoint_root, "lib", "html_report", "js") else NULL
  if (is.null(js_dir) || !dir.exists(js_dir)) skip("JS directory not found")

  export_file <- file.path(js_dir, "conjoint_export.js")
  if (!file.exists(export_file)) skip("conjoint_export.js not found")

  export_js <- paste(readLines(export_file, warn = FALSE), collapse = "\n")

  # Simulator export functions
  expect_true(grepl("exportSimulatorCSV", export_js, fixed = TRUE))
  expect_true(grepl("exportSimulatorExcel", export_js, fixed = TRUE))
  expect_true(grepl("buildSimulatorExportData", export_js, fixed = TRUE))

  # Shared refactored functions
  expect_true(grepl("exportCSVFromData", export_js, fixed = TRUE))
  expect_true(grepl("exportExcelFromData", export_js, fixed = TRUE))
})


test_that("pins JS includes expanded captureView and _addPinnedEntry", {
  js_dir <- if (!is.null(conjoint_root)) file.path(conjoint_root, "lib", "html_report", "js") else NULL
  if (is.null(js_dir) || !dir.exists(js_dir)) skip("JS directory not found")

  pins_file <- file.path(js_dir, "conjoint_pins.js")
  if (!file.exists(pins_file)) skip("conjoint_pins.js not found")

  pins_js <- paste(readLines(pins_file, warn = FALSE), collapse = "\n")

  # Expanded captureView handles new pin IDs
  expect_true(grepl("pin-overview", pins_js, fixed = TRUE))
  expect_true(grepl("pin-diagnostics", pins_js, fixed = TRUE))
  expect_true(grepl("pin-wtp", pins_js, fixed = TRUE))
  expect_true(grepl("pin-lc", pins_js, fixed = TRUE))
  expect_true(grepl("pin-simulator", pins_js, fixed = TRUE))

  # Slides integration
  expect_true(grepl("_addPinnedEntry", pins_js, fixed = TRUE))
})
