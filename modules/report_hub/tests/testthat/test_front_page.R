# Report Hub -- Front Page Builder Tests (03_front_page_builder.R)
# Tests for build_report_card() and build_front_page()

# ==============================================================================
# 4. FRONT PAGE BUILDER: build_report_card()
# ==============================================================================

test_that("build_report_card creates tracker card with metadata", {
  parsed <- list(
    report_key = "tracker",
    report_type = "tracker",
    metadata = list(
      report_type = "tracker",
      project_title = "Brand Tracker 2025",
      n_metrics = "42",
      n_waves = "5",
      n_segments = "3",
      baseline_label = "Q1 2023",
      latest_label = "Q4 2025"
    )
  )

  card_html <- build_report_card(parsed)

  expect_true(grepl("hub-card-type-tracker", card_html))
  expect_true(grepl("Tracker", card_html))
  expect_true(grepl("Brand Tracker 2025", card_html))
  expect_true(grepl("42 Metrics", card_html))
  expect_true(grepl("5 Waves", card_html))
  expect_true(grepl("3 Segments", card_html))
  expect_true(grepl("Q1 2023 - Baseline", card_html))
  expect_true(grepl("Q4 2025 - Latest Wave", card_html))
  expect_true(grepl("ReportHub.switchReport", card_html))
  expect_true(grepl("View Report", card_html))
})

test_that("build_report_card creates tabs/crosstabs card with metadata", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    metadata = list(
      report_type = "tabs",
      project_title = "Survey Crosstabs",
      total_n = "1500",
      n_questions = "35",
      n_banner_groups = "4",
      weighted = "true",
      fieldwork = "Jan-Mar 2025"
    )
  )

  card_html <- build_report_card(parsed)

  expect_true(grepl("hub-card-type-crosstabs", card_html))
  expect_true(grepl("Crosstabs", card_html))
  expect_true(grepl("Survey Crosstabs", card_html))
  expect_true(grepl("n=1,500", card_html))
  expect_true(grepl("35 Questions", card_html))
  expect_true(grepl("4 Banner Groups", card_html))
  expect_true(grepl("Weighted", card_html))
  expect_true(grepl("Fieldwork Jan-Mar 2025", card_html))
})

test_that("build_report_card handles single banner group (no plural)", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    metadata = list(
      report_type = "tabs",
      project_title = "Small Survey",
      n_banner_groups = "1"
    )
  )

  card_html <- build_report_card(parsed)

  # "1 Banner Group" not "1 Banner Groups"
  expect_true(grepl("1 Banner Group[^s]", card_html))
})

test_that("build_report_card uses report_key as fallback label", {
  parsed <- list(
    report_key = "my-report",
    report_type = "tabs",
    metadata = list(
      report_type = "tabs"
      # No project_title
    )
  )

  card_html <- build_report_card(parsed)

  expect_true(grepl("my-report", card_html))
})

test_that("build_report_card escapes HTML in labels", {
  parsed <- list(
    report_key = "test",
    report_type = "tracker",
    metadata = list(
      report_type = "tracker",
      project_title = "Test <script>alert('xss')</script>"
    )
  )

  card_html <- build_report_card(parsed)

  # Should be escaped, not raw HTML
  expect_false(grepl("<script>", card_html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;", card_html) || grepl("Test", card_html))
})

test_that("build_report_card handles tracker card with no metadata counts", {
  parsed <- list(
    report_key = "tracker",
    report_type = "tracker",
    metadata = list(
      report_type = "tracker",
      project_title = "Empty Tracker"
      # No n_metrics, n_waves, n_segments, no badge_bar
    )
  )

  card_html <- build_report_card(parsed)

  # Should still produce valid card HTML
  expect_true(grepl("hub-report-card", card_html))
  expect_true(grepl("Empty Tracker", card_html))
  # Stats line should be empty or have no stat entries
  expect_false(grepl("Metrics", card_html))
})


# ==============================================================================
# 4. FRONT PAGE BUILDER: build_front_page()
# ==============================================================================

test_that("build_front_page generates overview with report cards", {
  parsed_reports <- list(
    list(
      report_key = "tracker",
      report_type = "tracker",
      metadata = list(
        report_type = "tracker",
        project_title = "Tracker Report"
      ),
      content_panels = list()
    ),
    list(
      report_key = "tabs",
      report_type = "tabs",
      metadata = list(
        report_type = "tabs",
        project_title = "Tabs Report"
      ),
      content_panels = list()
    )
  )

  config <- list(
    settings = list(
      project_title = "Hub Project",
      company_name = "TestCo"
    )
  )

  overview_html <- build_front_page(config, parsed_reports)

  expect_true(grepl("hub-overview", overview_html))
  expect_true(grepl("hub-report-cards", overview_html))
  expect_true(grepl("Tracker Report", overview_html))
  expect_true(grepl("Tabs Report", overview_html))
  expect_true(grepl("hub-summary-area", overview_html))
})
