# ==============================================================================
# TABS MODULE - HTML REPORT TESTS
# ==============================================================================
#
# Tests for HTML report generation pipeline:
#   1. validate_html_report_inputs() — guard layer
#   2. build_banner_groups() — banner group transformation
#   3. transform_single_question() — question data transformation
#   4. transform_for_html() — full data transformation
#   5. generate_html_report() — end-to-end report generation
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_html_report.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

# Source shared + tabs dependencies
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))
source(file.path(turas_root, "modules/tabs/lib/crosstabs/crosstabs_config.R"))

# Source HTML report submodules
.tabs_lib_dir <- file.path(turas_root, "modules/tabs/lib")
assign(".tabs_lib_dir", .tabs_lib_dir, envir = globalenv())
source(file.path(turas_root, "modules/tabs/lib/html_report/99_html_report_main.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Minimal banner_info matching what create_banner_structure() returns
make_html_test_banner_info <- function() {
  list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("A", "B", "C"),
    column_to_banner = c("TOTAL::Total" = "TOTAL",
                         "Gender::Male" = "Gender",
                         "Gender::Female" = "Gender"),
    key_to_display = c("TOTAL::Total" = "Total",
                       "Gender::Male" = "Male",
                       "Gender::Female" = "Female"),
    banner_headers = data.frame(
      label = c("Total", "Gender"),
      start_col = c(1, 2),
      end_col = c(1, 3),
      stringsAsFactors = FALSE
    ),
    banner_info = list(
      Gender = list(
        internal_keys = c("Gender::Male", "Gender::Female"),
        columns = c("Male", "Female"),
        letters = c("B", "C"),
        question = data.frame(
          QuestionCode = "Gender",
          QuestionText = "What is your gender?",
          stringsAsFactors = FALSE
        )
      )
    )
  )
}

# Minimal all_results with one question
make_html_test_results <- function() {
  list(
    Q1 = list(
      question_code = "Q1",
      question_text = "How satisfied are you?",
      question_type = "Single_Response",
      table = data.frame(
        RowLabel = c("Satisfied", "Satisfied", "Satisfied",
                     "Neutral", "Neutral", "Neutral",
                     "Dissatisfied", "Dissatisfied", "Dissatisfied"),
        RowType = c("Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig.",
                    "Frequency", "Column %", "Sig."),
        RowSource = c("Satisfied", "Satisfied", "Satisfied",
                      "Neutral", "Neutral", "Neutral",
                      "Dissatisfied", "Dissatisfied", "Dissatisfied"),
        "TOTAL::Total" = c(60, 60.0, "",
                           25, 25.0, "",
                           15, 15.0, ""),
        "Gender::Male" = c(35, 70.0, "A",
                           10, 20.0, "",
                           5, 10.0, ""),
        "Gender::Female" = c(25, 50.0, "",
                             15, 30.0, "",
                             10, 20.0, "B"),
        check.names = FALSE,
        stringsAsFactors = FALSE
      ),
      bases = list(
        "TOTAL::Total" = list(unweighted = 100, weighted = 100, effective = 100),
        "Gender::Male" = list(unweighted = 50, weighted = 50, effective = 50),
        "Gender::Female" = list(unweighted = 50, weighted = 50, effective = 50)
      ),
      base_filter = NULL
    )
  )
}

# Minimal config
make_html_test_config <- function() {
  list(
    project_title = "Test HTML Report",
    brand_colour = "#323367",
    accent_colour = "#CC9900",
    company_name = "Test Company",
    client_name = NULL,
    researcher_logo_path = NULL,
    client_logo_path = NULL,
    include_summary = FALSE,
    show_charts = FALSE,
    enable_significance_testing = TRUE,
    embed_frequencies = TRUE,
    apply_weighting = FALSE,
    significance_min_base = 30,
    decimal_places_ratings = 1,
    decimal_places_percent = 0,
    chart_palette_preset = "warm",
    html_report = TRUE,
    min_base = 30,
    show_row_percentages = FALSE,
    analyst_name = NULL,
    analyst_email = NULL,
    analyst_phone = NULL,
    fieldwork_dates = NULL,
    closing_notes = NULL,
    verbatim_filename = NULL,
    qualitative_slides = NULL,
    index_descriptor = NULL,
    mean_descriptor = NULL,
    nps_descriptor = NULL,
    show_numeric_median = FALSE,
    show_numeric_mode = FALSE,
    show_index_scores = FALSE,
    show_nps_score = FALSE,
    show_net_positive = FALSE,
    show_chi_square = FALSE,
    show_frequencies = TRUE,
    show_column_percentages = TRUE,
    show_unweighted_n = FALSE,
    show_effective_n = FALSE,
    dashboard_green_net = 30,
    dashboard_amber_net = 0,
    dashboard_green_mean = 7,
    dashboard_amber_mean = 5,
    dashboard_scale_mean = 10,
    dashboard_green_index = 7,
    dashboard_amber_index = 5,
    dashboard_scale_index = 10,
    dashboard_green_custom = 60,
    dashboard_amber_custom = 40,
    dashboard_metrics = "NET POSITIVE"
  )
}


# ==============================================================================
# 1. validate_html_report_inputs — guard layer
# ==============================================================================

context("validate_html_report_inputs")

test_that("passes with valid inputs", {
  result <- validate_html_report_inputs(
    make_html_test_results(),
    make_html_test_banner_info(),
    make_html_test_config()
  )
  expect_equal(result$status, "PASS")
})

test_that("refuses NULL all_results", {
  result <- validate_html_report_inputs(
    NULL,
    make_html_test_banner_info(),
    make_html_test_config()
  )
  expect_equal(result$status, "REFUSED")
  expect_true(grepl("MISSING|INVALID", result$code))
})

test_that("refuses empty all_results", {
  result <- validate_html_report_inputs(
    list(),
    make_html_test_banner_info(),
    make_html_test_config()
  )
  expect_equal(result$status, "REFUSED")
})

test_that("refuses NULL banner_info", {
  result <- validate_html_report_inputs(
    make_html_test_results(),
    NULL,
    make_html_test_config()
  )
  expect_equal(result$status, "REFUSED")
})

test_that("refuses NULL config_obj", {
  result <- validate_html_report_inputs(
    make_html_test_results(),
    make_html_test_banner_info(),
    NULL
  )
  expect_equal(result$status, "REFUSED")
})


# ==============================================================================
# 2. build_banner_groups — banner group transformation
# ==============================================================================

context("build_banner_groups")

test_that("extracts banner groups from banner_info", {
  banner_info <- make_html_test_banner_info()
  groups <- build_banner_groups(banner_info)

  expect_true(is.list(groups))
  expect_true(length(groups) >= 1)

  # Should have at least Gender group
  group_names <- names(groups)
  expect_true(any(grepl("Gender|gender", group_names, ignore.case = TRUE)))
})

test_that("each group has required fields", {
  banner_info <- make_html_test_banner_info()
  groups <- build_banner_groups(banner_info)

  for (g_name in names(groups)) {
    g <- groups[[g_name]]
    expect_true("internal_keys" %in% names(g),
                info = paste("Missing internal_keys in group:", g_name))
    expect_true("display_labels" %in% names(g),
                info = paste("Missing display_labels in group:", g_name))
    expect_true(length(g$internal_keys) > 0)
  }
})


# ==============================================================================
# 3. transform_single_question
# ==============================================================================

context("transform_single_question")

test_that("transforms question with table and bases", {
  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- transform_single_question(
    all_results$Q1,
    banner_info,
    config
  )

  expect_true(is.list(result))
  expect_equal(result$q_code, "Q1")
  expect_equal(result$question_text, "How satisfied are you?")
  expect_true("table_data" %in% names(result))
  expect_true(is.data.frame(result$table_data))
  expect_true(nrow(result$table_data) > 0)
})

test_that("detects available statistics", {
  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- transform_single_question(
    all_results$Q1,
    banner_info,
    config
  )

  expect_true("stats" %in% names(result))
  expect_true(result$stats$has_freq)
  expect_true(result$stats$has_col_pct)
  expect_true(result$stats$has_sig)
})


# ==============================================================================
# 4. transform_for_html — full transformation
# ==============================================================================

context("transform_for_html")

test_that("transforms all results successfully", {
  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  html_data <- transform_for_html(all_results, banner_info, config)

  expect_true(is.list(html_data))
  expect_true("questions" %in% names(html_data))
  expect_true("banner_groups" %in% names(html_data))
  expect_true("n_questions" %in% names(html_data))
  expect_equal(html_data$n_questions, 1)
})

test_that("returns total_n", {
  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  html_data <- transform_for_html(all_results, banner_info, config)

  expect_true("total_n" %in% names(html_data))
  expect_equal(html_data$total_n, 100)
})

test_that("handles multiple questions", {
  all_results <- make_html_test_results()
  # Add a second question
  all_results$Q2 <- all_results$Q1
  all_results$Q2$question_code <- "Q2"
  all_results$Q2$question_text <- "Would you recommend?"

  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  html_data <- transform_for_html(all_results, banner_info, config)

  expect_equal(html_data$n_questions, 2)
  expect_true("Q1" %in% names(html_data$questions))
  expect_true("Q2" %in% names(html_data$questions))
})


# ==============================================================================
# 5. generate_html_report — end-to-end
# ==============================================================================

context("generate_html_report — end-to-end")

test_that("generates valid HTML file", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- generate_html_report(all_results, banner_info, config, tmp_html)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp_html))
  expect_true(file.size(tmp_html) > 0)
  expect_true(!is.null(result$file_size_mb))
  expect_equal(result$n_questions, 1)
})

test_that("HTML output contains expected content", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- generate_html_report(all_results, banner_info, config, tmp_html)

  html_content <- readLines(tmp_html, warn = FALSE)
  html_text <- paste(html_content, collapse = "\n")

  # Should contain DOCTYPE
  expect_true(grepl("<!DOCTYPE html>", html_text, fixed = TRUE))
  # Should contain question text
  expect_true(grepl("How satisfied are you?", html_text, fixed = TRUE))
  # Should contain project title
  expect_true(grepl("Test HTML Report", html_text, fixed = TRUE))
})

test_that("refuses invalid inputs gracefully", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  result <- generate_html_report(
    list(),  # empty results
    make_html_test_banner_info(),
    make_html_test_config(),
    tmp_html
  )

  expect_equal(result$status, "REFUSED")
  expect_false(file.exists(tmp_html))
})

test_that("handles multiple questions end-to-end", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  all_results <- make_html_test_results()
  all_results$Q2 <- all_results$Q1
  all_results$Q2$question_code <- "Q2"
  all_results$Q2$question_text <- "Would you recommend?"

  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()

  result <- generate_html_report(all_results, banner_info, config, tmp_html)

  expect_equal(result$status, "PASS")
  expect_equal(result$n_questions, 2)

  html_text <- paste(readLines(tmp_html, warn = FALSE), collapse = "\n")
  expect_true(grepl("Would you recommend?", html_text, fixed = TRUE))
})


# ==============================================================================
# INSIGHT AREA: GLOBAL COMMENTS ACROSS ALL BANNERS
# ==============================================================================

test_that("build_insight_area stores global comment under all banners", {
  # Simulate a global comment (banner = NA_character_, as serialized by load_comments_sheet)
  comment_entries <- list(
    list(banner = NA_character_, text = "This is a global insight.")
  )
  all_banners <- c("Cohort", "1 Year", "5 Year")

  insight_html <- as.character(build_insight_area(
    q_code = "Q24",
    comment_entries = comment_entries,
    first_banner = "Cohort",
    all_banners = all_banners
  ))

  # Extract the insight-store textarea content (the per-banner JSON)
  store_match <- regmatches(insight_html,
    regexpr('class="insight-store"[^>]*>([^<]*)<', insight_html, perl = TRUE))
  expect_true(nzchar(store_match), info = "insight-store textarea should have content")

  # Parse the JSON from the textarea
  json_content <- sub('.*class="insight-store"[^>]*>', '', store_match)
  json_content <- sub('<$', '', json_content)
  store_obj <- jsonlite::fromJSON(json_content)

  # Global comment should appear under ALL banner names

  expect_equal(store_obj[["Cohort"]], "This is a global insight.")
  expect_equal(store_obj[["1 Year"]], "This is a global insight.")
  expect_equal(store_obj[["5 Year"]], "This is a global insight.")
})


test_that("build_insight_area respects banner-specific over global comment", {
  # Banner-specific comment overrides global for that banner
  comment_entries <- list(
    list(banner = NA_character_, text = "Global insight for all."),
    list(banner = "1 Year", text = "Specific insight for 1 Year.")
  )
  all_banners <- c("Cohort", "1 Year", "5 Year")

  insight_html <- as.character(build_insight_area(
    q_code = "Q24",
    comment_entries = comment_entries,
    first_banner = "Cohort",
    all_banners = all_banners
  ))

  # Extract the insight-store JSON
  store_match <- regmatches(insight_html,
    regexpr('class="insight-store"[^>]*>([^<]*)<', insight_html, perl = TRUE))
  json_content <- sub('.*class="insight-store"[^>]*>', '', store_match)
  json_content <- sub('<$', '', json_content)
  store_obj <- jsonlite::fromJSON(json_content)

  # Cohort and 5 Year should have the global text
  expect_equal(store_obj[["Cohort"]], "Global insight for all.")
  expect_equal(store_obj[["5 Year"]], "Global insight for all.")
  # 1 Year should have the banner-specific text (overrides global)
  expect_equal(store_obj[["1 Year"]], "Specific insight for 1 Year.")
})


test_that("build_insight_area with no comments returns empty store", {
  insight_html <- as.character(build_insight_area(
    q_code = "Q10",
    comment_entries = NULL,
    first_banner = "Cohort",
    all_banners = c("Cohort", "1 Year")
  ))

  # Should have an insight-store textarea (empty)
  expect_true(grepl('class="insight-store"', insight_html, fixed = TRUE))
  # Should show "+ Add Insight" button
  expect_true(grepl("Add Insight", insight_html, fixed = TRUE))
})


test_that("load_comments_sheet uses NA for blank banner (not NULL)", {
  # Create a temporary config with Comments sheet
  tmp_config <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp_config), add = TRUE)

  wb <- openxlsx::createWorkbook()

  # Settings sheet (required)
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title"),
    Value = c("Test")
  ))

  # Selection sheet (required)
  openxlsx::addWorksheet(wb, "Selection")
  openxlsx::writeData(wb, "Selection", data.frame(
    QuestionCode = "Q1",
    Include = "Y"
  ))

  # Comments sheet with blank Banner column
  openxlsx::addWorksheet(wb, "Comments")
  openxlsx::writeData(wb, "Comments", data.frame(
    QuestionCode = c("Q1", "Q1"),
    Banner = c(NA, "Cohort"),
    Comment = c("Global comment text", "Cohort-specific comment")
  ))

  openxlsx::saveWorkbook(wb, tmp_config, overwrite = TRUE)

  comments <- load_comments_sheet(tmp_config)
  expect_false(is.null(comments))
  expect_true("Q1" %in% names(comments))

  # First entry should have banner = NA (not NULL) for JSON serialization
  first_entry <- comments[["Q1"]][[1]]
  expect_true(is.na(first_entry$banner),
    info = "Blank banner should be NA (serializes as JSON null), not NULL (serializes as {})")

  # Verify it serializes correctly to JSON
  json_str <- as.character(jsonlite::toJSON(comments[["Q1"]], auto_unbox = TRUE))
  expect_true(grepl('"banner":null', json_str, fixed = TRUE),
    info = "NA banner should serialize as JSON null")
  expect_false(grepl('"banner":{}', json_str, fixed = TRUE),
    info = "Should NOT serialize as empty object {}")
})


# ==============================================================================
# UI CONTROLS: HELP ICON, HIDE ROWS, HIDE COLUMNS
# ==============================================================================

context("UI controls — help icon placement")

test_that("help button is in report-tabs nav strip, not in header", {
  # Build the tab nav and header
  tab_nav_html <- as.character(build_report_tab_nav(
    brand_colour = "#323367", has_qualitative = FALSE, has_about = TRUE
  ))
  header_html <- as.character(build_header(
    project_title = "Test", brand_colour = "#323367",
    total_n = 100, n_questions = 5
  ))

  # Help button should be inside the report-tabs nav
  expect_true(grepl("help-btn", tab_nav_html, fixed = TRUE),
    info = "Help button (?) should be rendered inside the report-tabs nav strip")
  expect_true(grepl("toggleHelpOverlay", tab_nav_html, fixed = TRUE),
    info = "Help button onclick should call toggleHelpOverlay()")

 # Help button should NOT be in the header
  expect_false(grepl("help-btn", header_html, fixed = TRUE),
    info = "Help button should not be in the header banner")
})

test_that("help button appears after Pinned Views tab", {
  tab_nav_html <- as.character(build_report_tab_nav(
    brand_colour = "#323367", has_qualitative = FALSE, has_about = FALSE
  ))

  # Pinned Views should come before help-btn in the HTML
  pinned_pos <- regexpr("Pinned Views", tab_nav_html)
  help_pos <- regexpr("help-btn", tab_nav_html)
  expect_true(pinned_pos < help_pos,
    info = "Help button should appear after Pinned Views in the DOM")
})


context("UI controls — Hide rows and Hide columns toggles")

test_that("controls bar includes Hide rows toggle", {
  controls_html <- as.character(build_controls(
    has_any_freq = TRUE, has_any_pct = TRUE,
    has_any_sig = TRUE, brand_colour = "#323367"
  ))

  expect_true(grepl("Hide rows", controls_html, fixed = TRUE),
    info = "Controls bar should include 'Hide rows' toggle")
  expect_true(grepl("toggleAllRows", controls_html, fixed = TRUE),
    info = "Hide rows should call toggleAllRows()")
})

test_that("controls bar includes Hide columns toggle", {
  controls_html <- as.character(build_controls(
    has_any_freq = TRUE, has_any_pct = TRUE,
    has_any_sig = TRUE, brand_colour = "#323367"
  ))

  expect_true(grepl("Hide columns", controls_html, fixed = TRUE),
    info = "Controls bar should include 'Hide columns' toggle")
  expect_true(grepl("toggleAllColumns", controls_html, fixed = TRUE),
    info = "Hide columns should call toggleAllColumns()")
})

test_that("Hide columns appears next to Hide rows in controls", {
  controls_html <- as.character(build_controls(
    has_any_freq = TRUE, has_any_pct = TRUE,
    has_any_sig = TRUE, brand_colour = "#323367"
  ))

  rows_pos <- regexpr("Hide rows", controls_html)
  cols_pos <- regexpr("Hide columns", controls_html)
  count_pos <- regexpr("Show count", controls_html)

  expect_true(rows_pos < cols_pos,
    info = "Hide columns should appear after Hide rows")
  expect_true(cols_pos < count_pos,
    info = "Hide columns should appear before Show count")
})

test_that("controls with no percentages omit Hide rows and Hide columns", {
  controls_html <- as.character(build_controls(
    has_any_freq = TRUE, has_any_pct = FALSE,
    has_any_sig = TRUE, brand_colour = "#323367"
  ))

  expect_false(grepl("Hide rows", controls_html, fixed = TRUE),
    info = "Hide rows should not appear when has_any_pct is FALSE")
  expect_false(grepl("Hide columns", controls_html, fixed = TRUE),
    info = "Hide columns should not appear when has_any_pct is FALSE")
})


context("JavaScript — toggleAllRows targets all row types")

test_that("toggleAllRows JS targets category, net, and mean rows", {
  js_path <- file.path(turas_root, "modules/tabs/lib/html_report/js/core_navigation.js")
  js_content <- paste(readLines(js_path, warn = FALSE), collapse = "\n")

  # Must target all three row types
  expect_true(grepl("ct-row-category", js_content, fixed = TRUE),
    info = "toggleAllRows must target ct-row-category rows")
  expect_true(grepl("ct-row-net", js_content, fixed = TRUE),
    info = "toggleAllRows must target ct-row-net rows")
  expect_true(grepl("ct-row-mean", js_content, fixed = TRUE),
    info = "toggleAllRows must target ct-row-mean rows")

  # The selector in toggleAllRows should include all three
  expect_true(grepl("ct-row-category.*ct-row-net.*ct-row-mean", js_content, perl = TRUE),
    info = "toggleAllRows selector should include category, net, and mean row types")
})

test_that("toggleAllColumns JS function exists", {
  js_path <- file.path(turas_root, "modules/tabs/lib/html_report/js/core_navigation.js")
  js_content <- paste(readLines(js_path, warn = FALSE), collapse = "\n")

  expect_true(grepl("function toggleAllColumns", js_content, fixed = TRUE),
    info = "toggleAllColumns function must be defined in core_navigation.js")
})


context("End-to-end HTML — UI controls in generated report")

test_that("generated HTML has help button in nav strip and hide controls", {
  tmp_html <- tempfile(fileext = ".html")
  on.exit(unlink(tmp_html))

  all_results <- make_html_test_results()
  banner_info <- make_html_test_banner_info()
  config <- make_html_test_config()
  # Enable summary/dashboard so report-tabs nav strip is rendered
  config$include_summary <- TRUE

  result <- generate_html_report(all_results, banner_info, config, tmp_html)
  expect_equal(result$status, "PASS")

  html_text <- paste(readLines(tmp_html, warn = FALSE), collapse = "\n")

  # Help button should exist in the HTML
  expect_true(grepl("help-btn", html_text, fixed = TRUE),
    info = "Generated HTML should contain the help button")

  # Help button should be inside report-tabs div
  tabs_start <- regexpr('class="report-tabs"', html_text, fixed = TRUE)
  expect_true(tabs_start > 0, info = "report-tabs div should exist in HTML")
  # Grab 3000 chars after the start of report-tabs to capture the full div content
  tabs_chunk <- substr(html_text, tabs_start, tabs_start + 3000)
  expect_true(grepl("help-btn", tabs_chunk, fixed = TRUE),
    info = "Help button should be inside the report-tabs div")

  # Hide rows and Hide columns toggles should exist
  expect_true(grepl("toggleAllRows", html_text, fixed = TRUE),
    info = "Generated HTML should contain toggleAllRows")
  expect_true(grepl("toggleAllColumns", html_text, fixed = TRUE),
    info = "Generated HTML should contain toggleAllColumns")
  expect_true(grepl("Hide rows", html_text, fixed = TRUE))
  expect_true(grepl("Hide columns", html_text, fixed = TRUE))
})
