# ==============================================================================
# TESTS: HTML SIMULATOR (DEPRECATED - now part of combined report)
# ==============================================================================
# The standalone simulator has been merged into the combined HTML report.
# These tests verify backward compatibility of the deprecated wrapper.
# ==============================================================================

# Locate module root
.find_conjoint_root <- function() {
  tf <- tryCatch(testthat::test_path(".."), error = function(e) NULL)
  candidates <- c(
    if (!is.null(tf)) normalizePath(file.path(tf, ".."), mustWork = FALSE) else NULL,
    file.path(getwd(), "modules", "conjoint"),
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
  if (!exists("%||%", mode = "function")) {
    `%||%` <- function(x, y) if (is.null(x)) y else x
  }

  assign(".conjoint_lib_dir", file.path(conjoint_root, "lib"), envir = globalenv())

  # Load fixtures
  fixture_path <- file.path(conjoint_root, "tests", "fixtures", "synthetic_data",
                            "generate_conjoint_test_data.R")
  if (file.exists(fixture_path)) source(fixture_path, local = FALSE)

  # Load HTML report submodules
  html_report_dir <- file.path(conjoint_root, "lib", "html_report")
  for (f in c("00_html_guard.R", "01_data_transformer.R", "02_table_builder.R",
              "05_chart_builder.R", "03_page_builder.R", "04_html_writer.R",
              "99_html_report_main.R")) {
    fpath <- file.path(html_report_dir, f)
    if (file.exists(fpath)) source(fpath, local = FALSE)
  }

  # Load deprecated simulator wrapper
  sim_path <- file.path(conjoint_root, "lib", "html_simulator", "99_simulator_main.R")
  if (file.exists(sim_path)) source(sim_path, local = FALSE)
}


test_that("deprecated wrapper emits deprecation message", {
  if (!exists("generate_conjoint_html_simulator", mode = "function")) skip("generate_conjoint_html_simulator not loaded")
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  importance <- generate_importance_df(with_price = TRUE)
  config <- list(
    project_name = "Test Simulator",
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large"),
      Price = c("$10", "$20", "$30")
    ),
    simulation_method = "logit",
    brand_colour = "#2563eb"
  )

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  expect_message(
    result <- generate_conjoint_html_simulator(utils, importance, NULL, config, tmp_path),
    "DEPRECATED"
  )

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp_path))
})


test_that("deprecated wrapper produces combined report HTML", {
  if (!exists("generate_conjoint_html_simulator", mode = "function")) skip("generate_conjoint_html_simulator not loaded")
  if (!exists("generate_conjoint_html_report", mode = "function")) skip("generate_conjoint_html_report not loaded")

  utils <- generate_utilities_df(with_price = TRUE)
  importance <- generate_importance_df(with_price = TRUE)
  config <- list(
    project_name = "Test",
    brand_colour = "#2563eb",
    attribute_levels = list(
      Brand = c("Alpha", "Beta", "Gamma"),
      Size  = c("Small", "Medium", "Large"),
      Price = c("$10", "$20", "$30")
    )
  )

  tmp_path <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_path), add = TRUE)

  suppressMessages({
    result <- generate_conjoint_html_simulator(utils, importance, NULL, config, tmp_path)
  })

  # Should produce combined report, not old standalone simulator
  html <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl("panel-overview", html, fixed = TRUE))
  expect_true(grepl("panel-simulator", html, fixed = TRUE))
  expect_true(grepl("cj-simulator-data", html, fixed = TRUE))
})


test_that("simulator JS files have valid syntax", {
  js_dir <- if (!is.null(conjoint_root)) file.path(conjoint_root, "lib", "html_report", "js") else NULL

  if (is.null(js_dir) || !dir.exists(js_dir)) skip("JS directory not found")

  # Check simulator-specific JS files
  sim_files <- c("simulator_engine.js", "simulator_ui.js", "simulator_charts.js")
  for (fname in sim_files) {
    fpath <- file.path(js_dir, fname)
    if (!file.exists(fpath)) skip(sprintf("%s not found", fname))

    node_path <- "/usr/local/bin/node"
    if (!file.exists(node_path)) skip("node not found")

    result <- system2(node_path, args = c("--check", fpath), stdout = TRUE, stderr = TRUE)
    exit_code <- attr(result, "status") %||% 0L
    expect_equal(exit_code, 0L,
      info = sprintf("JS syntax error in %s: %s", fname, paste(result, collapse = "\n"))
    )
  }
})


test_that("simulator_ui.js contains profit analysis functions", {
  js_dir <- if (!is.null(conjoint_root)) file.path(conjoint_root, "lib", "html_report", "js") else NULL
  if (is.null(js_dir) || !dir.exists(js_dir)) skip("JS directory not found")

  ui_path <- file.path(js_dir, "simulator_ui.js")
  if (!file.exists(ui_path)) skip("simulator_ui.js not found")

  js_code <- paste(readLines(ui_path, warn = FALSE), collapse = "\n")

  # State variables

  expect_true(grepl("showProfitAnalysis", js_code, fixed = TRUE),
    info = "Missing showProfitAnalysis state variable")
  expect_true(grepl("productCosts", js_code, fixed = TRUE),
    info = "Missing productCosts state variable")

  # Public API functions
  expect_true(grepl("toggleProfitAnalysis", js_code, fixed = TRUE),
    info = "Missing toggleProfitAnalysis function")
  expect_true(grepl("setProductCost", js_code, fixed = TRUE),
    info = "Missing setProductCost function")

  # Callout note text
  expect_true(grepl("scenario comparison", js_code, fixed = TRUE),
    info = "Missing callout note about scenario comparison")
  expect_true(grepl("same currency", js_code, fixed = TRUE),
    info = "Missing callout note about currency consistency")

  # Profit bar colours (green for positive, red for negative)
  expect_true(grepl("#16a34a", js_code, fixed = TRUE),
    info = "Missing green profit bar colour")
  expect_true(grepl("#dc2626", js_code, fixed = TRUE),
    info = "Missing red profit bar colour")

  # Cost input renders with onchange for blur/enter update
  expect_true(grepl('setProductCost', js_code, fixed = TRUE),
    info = "Missing setProductCost handler on cost input")
})


test_that("profit analysis public API is exposed in SimUI return object", {
  js_dir <- if (!is.null(conjoint_root)) file.path(conjoint_root, "lib", "html_report", "js") else NULL
  if (is.null(js_dir) || !dir.exists(js_dir)) skip("JS directory not found")

  ui_path <- file.path(js_dir, "simulator_ui.js")
  if (!file.exists(ui_path)) skip("simulator_ui.js not found")

  js_code <- paste(readLines(ui_path, warn = FALSE), collapse = "\n")

  # Extract the return object block (between "return {" and "};")
  return_match <- regmatches(js_code, regexpr("return \\{[^}]+\\}", js_code))
  expect_true(length(return_match) > 0, info = "Could not find return object in SimUI")

  return_block <- return_match[1]
  expect_true(grepl("toggleProfitAnalysis", return_block, fixed = TRUE),
    info = "toggleProfitAnalysis not exposed in public API")
  expect_true(grepl("setProductCost", return_block, fixed = TRUE),
    info = "setProductCost not exposed in public API")
})
