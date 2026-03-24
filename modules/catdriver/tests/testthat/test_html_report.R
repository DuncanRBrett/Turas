# ==============================================================================
# CATDRIVER HTML REPORT TEST SUITE
# ==============================================================================
#
# Tests the html_report submodule: guard layer, table builders, page components,
# section builders, chart builder, CSS builder, HTML writer, and data transformer.
#
# Uses synthetic/mock data throughout - no external fixtures required.
# Relies on module_root and turas_root from helper-paths.R.
#
# Run with: testthat::test_file("modules/catdriver/tests/testthat/test_html_report.R")
# ==============================================================================

library(testthat)

# Source html_report submodule files (helper-paths.R already sources R/ files)
html_report_dir <- file.path(module_root, "lib", "html_report")

if (!dir.exists(html_report_dir)) {
  skip("html_report directory not found")
}

# Source all html_report files in order
html_report_files <- c(
  "00_html_guard.R", "01_data_transformer.R", "02_table_builder.R",
  "03a_page_styling.R", "03b_page_components.R", "03c_section_builders.R",
  "04_html_writer.R", "05_chart_builder.R"
)

# Ensure callout registry is available (required by section builders)
callout_dir <- file.path(turas_root, "modules", "shared", "lib", "callouts")
if (dir.exists(callout_dir) && !exists("turas_callout", mode = "function")) {
  for (cf in sort(list.files(callout_dir, pattern = "\\.R$", full.names = TRUE))) {
    tryCatch(source(cf), error = function(e) NULL)
  }
}
# Stub turas_callout if still missing (e.g., dependency not available)
if (!exists("turas_callout", mode = "function")) {
  turas_callout <- function(...) ""
}

for (f in html_report_files) {
  fpath <- file.path(html_report_dir, f)
  if (file.exists(fpath)) {
    tryCatch(source(fpath), error = function(e) {
      cat("Warning: Could not source", f, ":", e$message, "\n")
    })
  }
}

# Ensure htmltools is available (required for most functions)
if (!requireNamespace("htmltools", quietly = TRUE)) {
  skip("htmltools package required for html_report tests")
}

# ==============================================================================
# TEST DATA GENERATORS
# ==============================================================================

# Minimal mock results object that passes guard validation
mock_catdriver_results <- function() {
  imp_df <- data.frame(
    rank = 1:3,
    variable = c("age_group", "income", "region"),
    label = c("Age Group", "Income", "Region"),
    importance_pct = c(45.2, 32.1, 22.7),
    chi_square = c(28.5, 18.2, 11.3),
    p_value = c(0.001, 0.01, 0.05),
    significance = c("***", "**", "*"),
    effect_size = c("Large", "Medium", "Small"),
    stringsAsFactors = FALSE
  )

  list(
    importance = imp_df,
    factor_patterns = list(
      age_group = list(
        label = "Age Group",
        reference = "18-34",
        patterns = data.frame(
          category = c("18-34", "35-54", "55+"),
          n = c(100, 120, 80),
          pct_of_total = c(33.3, 40.0, 26.7),
          is_reference = c(TRUE, FALSE, FALSE),
          pct_Yes = c(45, 62, 38),
          pct_No = c(55, 38, 62),
          odds_ratio = c(1.0, 2.1, 0.7),
          or_lower = c(NA, 1.3, 0.4),
          or_upper = c(NA, 3.4, 1.2),
          effect = c("", "Medium", "Small"),
          stringsAsFactors = FALSE
        )
      )
    ),
    model_result = list(converged = TRUE),
    odds_ratios = data.frame(
      variable = c("age_group", "age_group", "income", "income"),
      factor_label = c("Age Group", "Age Group", "Income", "Income"),
      comparison = c("35-54", "55+", "Medium", "High"),
      reference = c("18-34", "18-34", "Low", "Low"),
      or_value = c(2.1, 0.7, 1.5, 3.2),
      or_lower = c(1.3, 0.4, 0.9, 1.8),
      or_upper = c(3.4, 1.2, 2.5, 5.7),
      or_formatted = c("2.10", "0.70", "1.50", "3.20"),
      ci_formatted = c("1.30-3.40", "0.40-1.20", "0.90-2.50", "1.80-5.70"),
      p_value = c(0.003, 0.19, 0.12, 0.001),
      p_formatted = c("0.003", "0.190", "0.120", "<0.001"),
      significance = c("**", "", "", "***"),
      effect = c("Medium", "Small", "Small", "Large"),
      stringsAsFactors = FALSE
    ),
    diagnostics = list(
      original_n = 320,
      complete_n = 300,
      pct_complete = 93.8,
      convergence = TRUE,
      has_small_cells = FALSE,
      n_small_cell_vars = 0
    ),
    prep_data = data.frame(outcome = factor(sample(c("Yes", "No"), 300, TRUE)))
  )
}

mock_config <- function() {
  list(
    driver_vars = c("age_group", "income", "region"),
    outcome_var = "outcome",
    brand_colour = "#323367",
    accent_colour = "#CC9900",
    report_title = "Test Report",
    company_name = "Test Company",
    client_name = "Test Client",
    researcher_name = "Test Researcher",
    output_file = "test_report.html",
    min_sample_size = 30
  )
}

# Transformed importance data (as returned by transformer)
mock_importance_list <- function() {
  list(
    list(rank = 1, variable = "age_group", label = "Age Group",
         importance_pct = 45.2, chi_square = 28.5, p_value = 0.001,
         p_formatted = "<0.001", significance = "***", effect_size = "Large"),
    list(rank = 2, variable = "income", label = "Income",
         importance_pct = 32.1, chi_square = 18.2, p_value = 0.01,
         p_formatted = "0.010", significance = "**", effect_size = "Medium"),
    list(rank = 3, variable = "region", label = "Region",
         importance_pct = 22.7, chi_square = 11.3, p_value = 0.05,
         p_formatted = "0.050", significance = "*", effect_size = "Small")
  )
}

# Transformed odds ratio entries
mock_odds_ratio_list <- function() {
  list(
    list(factor_label = "Age Group", comparison = "35-54", reference = "18-34",
         or_value = 2.1, or_formatted = "2.10", ci_formatted = "1.30-3.40",
         p_formatted = "0.003", significance = "**", effect = "Medium",
         or_lower = 1.3, or_upper = 3.4),
    list(factor_label = "Age Group", comparison = "55+", reference = "18-34",
         or_value = 0.7, or_formatted = "0.70", ci_formatted = "0.40-1.20",
         p_formatted = "0.190", significance = "", effect = "Small",
         or_lower = 0.4, or_upper = 1.2),
    list(factor_label = "Income", comparison = "High", reference = "Low",
         or_value = 3.2, or_formatted = "3.20", ci_formatted = "1.80-5.70",
         p_formatted = "<0.001", significance = "***", effect = "Large",
         or_lower = 1.8, or_upper = 5.7)
  )
}

# Mock pattern data (as returned by transformer)
mock_pattern_data <- function() {
  list(
    label = "Age Group",
    variable = "age_group",
    reference = "18-34",
    outcome_categories = c("Yes", "No"),
    categories = list(
      list(category = "18-34", n = 100, pct_of_total = 33.3,
           is_reference = TRUE, outcome_pcts = list(Yes = 45, No = 55),
           odds_ratio = 1.0, or_lower = NA, or_upper = NA, effect = ""),
      list(category = "35-54", n = 120, pct_of_total = 40.0,
           is_reference = FALSE, outcome_pcts = list(Yes = 62, No = 38),
           odds_ratio = 2.1, or_lower = 1.3, or_upper = 3.4, effect = "Medium"),
      list(category = "55+", n = 80, pct_of_total = 26.7,
           is_reference = FALSE, outcome_pcts = list(Yes = 38, No = 62),
           odds_ratio = 0.7, or_lower = 0.4, or_upper = 1.2, effect = "Small")
    )
  )
}

# Mock probability lift data
mock_lift_data <- function() {
  list(
    label = "Age Group",
    variable = "age_group",
    reference = "18-34",
    categories = list(
      list(level = "18-34", is_reference = TRUE, mean_prob = 0.45,
           ref_prob = 0.45, lift_pct = 0),
      list(level = "35-54", is_reference = FALSE, mean_prob = 0.62,
           ref_prob = 0.45, lift_pct = 17.0),
      list(level = "55+", is_reference = FALSE, mean_prob = 0.38,
           ref_prob = 0.45, lift_pct = -7.0)
    )
  )
}

# Mock diagnostics data
mock_diagnostics <- function() {
  list(
    original_n = 320,
    complete_n = 300,
    pct_complete = 93.8,
    convergence = TRUE,
    has_small_cells = FALSE,
    n_small_cell_vars = 0
  )
}

# Mock model_info
mock_model_info <- function() {
  list(
    outcome_type = "binary",
    n_drivers = 3,
    n_observations = 300,
    weight_var = NULL,
    fit_statistics = list(mcfadden_r2 = 0.25)
  )
}

# Helper to render htmltools tag to string
render_tag <- function(tag) {
  as.character(htmltools::renderTags(tag)$html)
}


# ==============================================================================
# 1. GUARD LAYER TESTS
# ==============================================================================

test_that("validate_catdriver_html_inputs returns PASS for valid inputs", {
  results <- mock_catdriver_results()
  config <- mock_config()
  output_path <- file.path(tempdir(), "test_report.html")

  result <- validate_catdriver_html_inputs(results, config, output_path)
  expect_equal(result$status, "PASS")
})

test_that("validate_catdriver_html_inputs refuses NULL results", {
  config <- mock_config()
  output_path <- file.path(tempdir(), "test_report.html")

  result <- validate_catdriver_html_inputs(NULL, config, output_path)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_MISSING")
})

test_that("validate_catdriver_html_inputs refuses non-list results", {
  config <- mock_config()
  output_path <- file.path(tempdir(), "test_report.html")

  result <- validate_catdriver_html_inputs("not a list", config, output_path)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_MISSING")
})

test_that("validate_catdriver_html_inputs refuses results with missing fields", {
  results <- list(importance = data.frame(x = 1))  # missing other required fields
  config <- mock_config()
  output_path <- file.path(tempdir(), "test_report.html")

  result <- validate_catdriver_html_inputs(results, config, output_path)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
  expect_true(grepl("missing required fields", result$message, ignore.case = TRUE))
})

test_that("validate_catdriver_html_inputs refuses empty importance data frame", {
  results <- mock_catdriver_results()
  results$importance <- data.frame()  # empty
  config <- mock_config()
  output_path <- file.path(tempdir(), "test_report.html")

  result <- validate_catdriver_html_inputs(results, config, output_path)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
})

test_that("validate_catdriver_html_inputs refuses NULL config", {
  results <- mock_catdriver_results()
  output_path <- file.path(tempdir(), "test_report.html")

  result <- validate_catdriver_html_inputs(results, NULL, output_path)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_INVALID")
})

test_that("validate_catdriver_html_inputs refuses empty output path", {
  results <- mock_catdriver_results()
  config <- mock_config()

  result <- validate_catdriver_html_inputs(results, config, "")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})


# ==============================================================================
# 2. CSS BUILDER TESTS
# ==============================================================================

test_that("build_cd_css returns a non-empty CSS string", {
  css <- build_cd_css("#323367", "#CC9900")
  expect_type(css, "character")
  expect_true(nchar(css) > 100)
})

test_that("build_cd_css injects brand and accent colours", {
  css <- build_cd_css("#AABBCC", "#DDEEFF")
  expect_true(grepl("#AABBCC", css, fixed = TRUE) || grepl("AABBCC", css, ignore.case = TRUE))
  expect_true(grepl("#DDEEFF", css, fixed = TRUE) || grepl("DDEEFF", css, ignore.case = TRUE))
})

test_that("build_cd_css contains key CSS class selectors", {
  css <- build_cd_css("#323367", "#CC9900")
  expect_true(grepl("cd-body", css, fixed = TRUE))
  expect_true(grepl("cd-section-nav", css, fixed = TRUE))
})


# ==============================================================================
# 3. TABLE BUILDER TESTS
# ==============================================================================

test_that("build_cd_importance_table returns valid HTML table tag", {
  importance <- mock_importance_list()
  table <- build_cd_importance_table(importance)

  expect_s3_class(table, "shiny.tag")
  html <- render_tag(table)
  expect_true(grepl("<table", html, fixed = TRUE))
  expect_true(grepl("cd-importance-table", html, fixed = TRUE))
  # Check all 3 drivers are present
  expect_true(grepl("Age Group", html, fixed = TRUE))
  expect_true(grepl("Income", html, fixed = TRUE))
  expect_true(grepl("Region", html, fixed = TRUE))
})

test_that("build_cd_importance_table renders rank and percentage", {
  importance <- mock_importance_list()
  html <- render_tag(build_cd_importance_table(importance))
  expect_true(grepl("45.2%", html, fixed = TRUE))
  expect_true(grepl("28.50", html, fixed = TRUE))  # chi-square
})

test_that("build_cd_pattern_table returns valid HTML for pattern data", {
  pattern <- mock_pattern_data()
  table <- build_cd_pattern_table(pattern, "age_group")

  expect_s3_class(table, "shiny.tag")
  html <- render_tag(table)
  expect_true(grepl("<table", html, fixed = TRUE))
  expect_true(grepl("cd-pattern-table", html, fixed = TRUE))
  # Check categories present
  expect_true(grepl("18-34", html, fixed = TRUE))
  expect_true(grepl("35-54", html, fixed = TRUE))
  # Check reference row marker
  expect_true(grepl("cd-tr-reference", html, fixed = TRUE))
})

test_that("build_cd_odds_ratio_table returns valid HTML without bootstrap", {
  or_list <- mock_odds_ratio_list()
  table <- build_cd_odds_ratio_table(or_list, has_bootstrap = FALSE)

  expect_s3_class(table, "shiny.tag")
  html <- render_tag(table)
  expect_true(grepl("<table", html, fixed = TRUE))
  expect_true(grepl("2.10", html, fixed = TRUE))
  expect_true(grepl("3.20", html, fixed = TRUE))
  # No bootstrap columns
  expect_false(grepl("Boot OR", html, fixed = TRUE))
})

test_that("build_cd_odds_ratio_table includes bootstrap columns when enabled", {
  or_list <- mock_odds_ratio_list()
  # Add bootstrap fields
  for (i in seq_along(or_list)) {
    or_list[[i]]$boot_median_or <- or_list[[i]]$or_value * 1.02
    or_list[[i]]$boot_ci_lower <- or_list[[i]]$or_lower * 0.95
    or_list[[i]]$boot_ci_upper <- or_list[[i]]$or_upper * 1.05
    or_list[[i]]$sign_stability <- 0.95
  }
  table <- build_cd_odds_ratio_table(or_list, has_bootstrap = TRUE)
  html <- render_tag(table)
  expect_true(grepl("Boot OR", html, fixed = TRUE))
  expect_true(grepl("Stability", html, fixed = TRUE))
})

test_that("build_cd_probability_lift_table renders reference and non-reference rows", {
  lift <- mock_lift_data()
  table <- build_cd_probability_lift_table(lift, "age_group")

  expect_s3_class(table, "shiny.tag")
  html <- render_tag(table)
  expect_true(grepl("cd-lift-table", html, fixed = TRUE))
  expect_true(grepl("(ref)", html, fixed = TRUE))
  expect_true(grepl("Baseline", html, fixed = TRUE))
  # Non-reference row with lift
  expect_true(grepl("+17.0 pp", html, fixed = TRUE) ||
              grepl("17.0", html, fixed = TRUE))
})

test_that("build_cd_diagnostics_table renders status badges", {
  diag <- mock_diagnostics()
  model_info <- mock_model_info()
  config <- mock_config()

  table <- build_cd_diagnostics_table(diag, model_info, config)
  expect_s3_class(table, "shiny.tag")
  html <- render_tag(table)
  expect_true(grepl("cd-diagnostics-table", html, fixed = TRUE))
  expect_true(grepl("PASS", html, fixed = TRUE))
  expect_true(grepl("Sample size", html, fixed = TRUE))
  expect_true(grepl("Convergence", html, fixed = TRUE))
})

test_that("build_cd_diagnostics_table shows FAIL for small sample", {
  diag <- mock_diagnostics()
  diag$complete_n <- 10  # below min_sample_size of 30
  model_info <- mock_model_info()
  config <- mock_config()

  table <- build_cd_diagnostics_table(diag, model_info, config)
  html <- render_tag(table)
  expect_true(grepl("FAIL", html, fixed = TRUE))
})


# ==============================================================================
# 4. PAGE COMPONENT TESTS
# ==============================================================================

test_that("build_cd_section_nav returns nav tag with correct links", {
  nav <- build_cd_section_nav("#323367")

  expect_s3_class(nav, "shiny.tag")
  html <- render_tag(nav)
  expect_true(grepl("<nav", html, fixed = TRUE))
  expect_true(grepl("cd-section-nav", html, fixed = TRUE))
  expect_true(grepl("Summary", html, fixed = TRUE))
  expect_true(grepl("Importance", html, fixed = TRUE))
  expect_true(grepl("Odds Ratios", html, fixed = TRUE))
  expect_true(grepl("Diagnostics", html, fixed = TRUE))
  # No subgroup link by default
  expect_false(grepl("Subgroups", html, fixed = TRUE))
})

test_that("build_cd_section_nav includes subgroup link when has_subgroup=TRUE", {
  nav <- build_cd_section_nav("#323367", has_subgroup = TRUE)
  html <- render_tag(nav)
  expect_true(grepl("Subgroups", html, fixed = TRUE))
})

test_that("build_cd_section_title_row returns title with pin button", {
  row <- build_cd_section_title_row("Test Section", "test-section")
  html <- render_tag(row)
  expect_true(grepl("Test Section", html, fixed = TRUE))
  expect_true(grepl("cd-pin-btn", html, fixed = TRUE))
})

test_that("build_cd_section_title_row hides pin when show_pin=FALSE", {
  row <- build_cd_section_title_row("Test Section", "test-section", show_pin = FALSE)
  html <- render_tag(row)
  expect_true(grepl("Test Section", html, fixed = TRUE))
  expect_false(grepl("cd-pin-btn", html, fixed = TRUE))
})

test_that("build_cd_insight_area returns editable insight container", {
  area <- build_cd_insight_area("exec-summary")
  html <- render_tag(area)
  expect_true(grepl("cd-insight-area", html, fixed = TRUE))
  expect_true(grepl("contenteditable", html, fixed = TRUE))
  expect_true(grepl("Add Insight", html, fixed = TRUE))
})

test_that("build_cd_help_overlay returns a modal overlay", {
  overlay <- build_cd_help_overlay()
  html <- render_tag(overlay)
  expect_true(grepl("cd-help-overlay", html, fixed = TRUE))
  expect_true(grepl("Quick Guide", html, fixed = TRUE))
})

test_that("build_cd_action_bar returns save button", {
  bar <- build_cd_action_bar("My Report")
  html <- render_tag(bar)
  expect_true(grepl("cd-action-bar", html, fixed = TRUE))
  expect_true(grepl("Save Report", html, fixed = TRUE))
})

test_that("build_cd_footer renders company and client names", {
  config <- list(company_name = "Acme Corp", client_name = "BigClient")
  footer <- build_cd_footer(config)
  html <- render_tag(footer)
  expect_true(grepl("cd-footer", html, fixed = TRUE))
  expect_true(grepl("Acme Corp", html, fixed = TRUE))
  expect_true(grepl("BigClient", html, fixed = TRUE))
  expect_true(grepl("TURAS", html, fixed = TRUE))
})

test_that("build_cd_footer uses defaults when config is empty", {
  footer <- build_cd_footer(list())
  html <- render_tag(footer)
  expect_true(grepl("Research LampPost", html, fixed = TRUE))
})


# ==============================================================================
# 5. CHIP BAR / FILTER COMPONENT TESTS
# ==============================================================================

test_that("build_cd_or_chip_bar returns NULL for empty odds ratios", {
  result <- build_cd_or_chip_bar(NULL)
  expect_null(result)

  result2 <- build_cd_or_chip_bar(list())
  expect_null(result2)
})

test_that("build_cd_or_chip_bar returns NULL for single factor", {
  or_list <- list(
    list(factor_label = "Age Group", comparison = "35-54", reference = "18-34")
  )
  result <- build_cd_or_chip_bar(or_list)
  expect_null(result)
})

test_that("build_cd_or_chip_bar returns chips for multiple factors", {
  or_list <- mock_odds_ratio_list()
  bar <- build_cd_or_chip_bar(or_list)
  expect_s3_class(bar, "shiny.tag")
  html <- render_tag(bar)
  expect_true(grepl("cd-or-chip-bar", html, fixed = TRUE))
  expect_true(grepl("Age Group", html, fixed = TRUE))
  expect_true(grepl("Income", html, fixed = TRUE))
})

test_that("build_cd_lift_chip_bar returns NULL for empty input", {
  expect_null(build_cd_lift_chip_bar(NULL))
  expect_null(build_cd_lift_chip_bar(list()))
})

test_that("build_cd_importance_filter_bar renders filter options", {
  bar <- build_cd_importance_filter_bar(n_drivers = 10)
  html <- render_tag(bar)
  expect_true(grepl("All", html, fixed = TRUE))
  expect_true(grepl("Top 3", html, fixed = TRUE))
  expect_true(grepl("Significant", html, fixed = TRUE))
  # n_drivers > 8 should include Top 8
  expect_true(grepl("Top 8", html, fixed = TRUE))
})


# ==============================================================================
# 6. CHART BUILDER TESTS
# ==============================================================================

test_that("build_cd_importance_chart returns SVG HTML for valid data", {
  importance <- mock_importance_list()
  chart <- build_cd_importance_chart(importance, "#323367")

  expect_true(!is.null(chart))
  html <- as.character(chart)
  expect_true(grepl("<svg", html, fixed = TRUE))
  expect_true(grepl("Age Group", html, fixed = TRUE))
})

test_that("build_cd_importance_chart returns NULL for empty importance", {
  result <- build_cd_importance_chart(list(), "#323367")
  expect_null(result)
})

test_that("build_cd_forest_plot returns SVG HTML for valid odds ratios", {
  or_list <- mock_odds_ratio_list()
  chart <- build_cd_forest_plot(or_list, "#323367", "#CC9900")

  expect_true(!is.null(chart))
  html <- as.character(chart)
  expect_true(grepl("<svg", html, fixed = TRUE))
})


# ==============================================================================
# 7. HTML WRITER TESTS
# ==============================================================================

test_that("write_cd_html_report refuses empty output path", {
  page <- htmltools::tags$div("test content")
  result <- write_cd_html_report(page, "")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("write_cd_html_report refuses NULL output path", {
  page <- htmltools::tags$div("test content")
  result <- write_cd_html_report(page, NULL)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("write_cd_html_report writes a valid HTML file", {
  page <- htmltools::tagList(
    htmltools::tags$head(htmltools::tags$title("Test")),
    htmltools::tags$body(htmltools::tags$div("Hello world"))
  )
  output_path <- file.path(tempdir(), paste0("test_catdriver_", Sys.getpid(), ".html"))
  on.exit(unlink(output_path), add = TRUE)

  result <- write_cd_html_report(page, output_path)
  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))
  expect_true(result$file_size_bytes > 0)
  expect_true(result$file_size_mb >= 0)

  # Check content is valid HTML
  content <- paste(readLines(output_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", content, fixed = TRUE))
  expect_true(grepl("Hello world", content, fixed = TRUE))
})

test_that("write_cd_html_report creates output directory if needed", {
  nested_dir <- file.path(tempdir(), paste0("nested_", Sys.getpid()), "subdir")
  output_path <- file.path(nested_dir, "report.html")
  on.exit(unlink(dirname(nested_dir), recursive = TRUE), add = TRUE)

  page <- htmltools::tags$div("test")
  result <- write_cd_html_report(page, output_path)
  expect_equal(result$status, "PASS")
  expect_true(file.exists(output_path))
})


# ==============================================================================
# 8. RESOLVE LOGO URI TESTS
# ==============================================================================

test_that("resolve_logo_uri returns NULL for NULL input", {
  expect_null(resolve_logo_uri(NULL))
})

test_that("resolve_logo_uri returns NULL for empty string", {
  expect_null(resolve_logo_uri(""))
})

test_that("resolve_logo_uri passes through data URIs", {
  uri <- "data:image/png;base64,abc123"
  expect_equal(resolve_logo_uri(uri), uri)
})

test_that("resolve_logo_uri passes through http/https URLs", {
  url <- "https://example.com/logo.png"
  expect_equal(resolve_logo_uri(url), url)
})

test_that("resolve_logo_uri returns NULL for non-existent file", {
  expect_null(resolve_logo_uri("/no/such/file/logo.png"))
})


# ==============================================================================
# 9. QUALITATIVE PANEL TESTS
# ==============================================================================

test_that("build_cd_qualitative_panel renders empty state when no slides", {
  panel <- build_cd_qualitative_panel(NULL, "#323367")
  html <- render_tag(panel)
  expect_true(grepl("cd-qualitative", html, fixed = TRUE))
  expect_true(grepl("No slides yet", html, fixed = TRUE))
  expect_true(grepl("Add Slide", html, fixed = TRUE))
})

test_that("build_cd_qualitative_panel renders provided slides", {
  slides <- list(
    list(id = "slide-1", title = "Key Finding", content = "This is important"),
    list(id = "slide-2", title = "Another Point", content = "Details here")
  )
  panel <- build_cd_qualitative_panel(slides, "#323367")
  html <- render_tag(panel)
  expect_true(grepl("Added Slides", html, fixed = TRUE))
})


# ==============================================================================
# 10. COMPONENT PIN BUTTON TESTS
# ==============================================================================

test_that("build_cd_component_pin_btn returns chart pin", {
  btn <- build_cd_component_pin_btn("importance", "chart")
  html <- render_tag(btn)
  expect_true(grepl("cd-component-pin", html, fixed = TRUE))
  expect_true(grepl("Chart", html, fixed = TRUE))
})

test_that("build_cd_component_pin_btn returns table pin", {
  btn <- build_cd_component_pin_btn("odds-ratios", "table")
  html <- render_tag(btn)
  expect_true(grepl("Table", html, fixed = TRUE))
})


# ==============================================================================
# 11. INTERPRETATION SECTION TEST
# ==============================================================================

test_that("build_cd_interpretation_section returns interpretation guide HTML", {
  section <- build_cd_interpretation_section("#323367")
  html <- render_tag(section)
  expect_true(grepl("cd-interpretation", html, fixed = TRUE))
  expect_true(grepl("How to Interpret", html, fixed = TRUE))
  expect_true(grepl("DO", html, fixed = TRUE))
  expect_true(grepl("DON", html, fixed = TRUE))
  # Pin button should be hidden on interpretation
  expect_false(grepl("cd-pin-btn", html, fixed = TRUE))
})


# ==============================================================================
# 12. SECTION BUILDER EDGE CASES
# ==============================================================================

test_that("build_cd_patterns_section returns NULL when no patterns exist", {
  html_data <- list(patterns = list())
  tables <- list(patterns = list())
  result <- build_cd_patterns_section(html_data, tables)
  expect_null(result)
})

test_that("build_cd_importance_section builds section with tables and charts", {
  tables <- list(
    importance = build_cd_importance_table(mock_importance_list())
  )
  charts <- list(
    importance = build_cd_importance_chart(mock_importance_list(), "#323367")
  )

  section <- build_cd_importance_section(tables, charts, "#323367", n_drivers = 3)
  html <- render_tag(section)
  expect_true(grepl("cd-importance", html, fixed = TRUE))
  expect_true(grepl("Driver Importance", html, fixed = TRUE))
})

test_that("build_cd_importance_section renders filter bar for many drivers", {
  tables <- list(
    importance = build_cd_importance_table(mock_importance_list())
  )
  charts <- list(importance = NULL)

  section <- build_cd_importance_section(tables, charts, "#323367", n_drivers = 10)
  html <- render_tag(section)
  # Filter bar should appear for n_drivers > 5
  expect_true(grepl("cd-importance-filter", html, fixed = TRUE) ||
              grepl("cd-or-chip-bar", html, fixed = TRUE))
})
