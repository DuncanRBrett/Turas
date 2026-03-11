# ==============================================================================
# MAXDIFF TESTS - HTML REPORT
# ==============================================================================

test_that("transform_maxdiff_for_html returns correct structure", {
  skip_if(!exists("transform_maxdiff_for_html", mode = "function"))

  td <- generate_test_data()

  # Build minimal results object
  results <- list(
    count_scores = data.frame(
      Item_ID = td$items$Item_ID,
      Item_Label = td$items$Item_Label,
      Best_Pct = runif(td$n_items, 5, 30),
      Worst_Pct = runif(td$n_items, 5, 30),
      BW_Score = rnorm(td$n_items),
      stringsAsFactors = FALSE
    ),
    hb_results = list(
      population_utilities = data.frame(
        Item_ID = td$items$Item_ID,
        Item_Label = td$items$Item_Label,
        HB_Utility_Mean = td$true_utils,
        HB_Utility_SD = rep(0.3, td$n_items),
        stringsAsFactors = FALSE
      ),
      individual_utilities = td$individual_utils
    ),
    study_summary = list(n_respondents = td$n_resp, n_tasks = td$n_tasks, n_items = td$n_items)
  )

  config <- list(
    project_settings = list(
      Project_Name = "Test Project",
      Brand_Colour = "#1e3a5f",
      Accent_Colour = "#2aa198"
    ),
    items = td$items,
    output_settings = list()
  )

  html_data <- transform_maxdiff_for_html(results, config)

  expect_true(is.list(html_data))
  expect_true("meta" %in% names(html_data))
  expect_true("summary" %in% names(html_data))
  expect_true("preferences" %in% names(html_data))
  expect_true("diagnostics" %in% names(html_data))

  expect_equal(html_data$meta$project_name, "Test Project")
  expect_equal(html_data$meta$n_total, td$n_resp)
})

test_that("build_preference_scores_table generates valid HTML", {
  skip_if(!exists("build_preference_scores_table", mode = "function"))

  scores <- data.frame(
    Item_ID = c("A", "B", "C"),
    Item_Label = c("Alpha", "Beta", "Gamma"),
    Utility = c(2.0, 1.0, -0.5),
    SE = c(0.3, 0.2, 0.4),
    Rescaled = c(100, 60, 0),
    Rank = c(1, 2, 3),
    Pref_Share = c(50, 30, 20),
    stringsAsFactors = FALSE
  )

  html <- build_preference_scores_table(scores)

  expect_true(is.character(html))
  expect_true(grepl("<table", html))
  expect_true(grepl("Alpha", html))
  expect_true(grepl("Beta", html))
})

test_that("build_diverging_chart generates SVG", {
  skip_if(!exists("build_diverging_chart", mode = "function"))

  count_data <- data.frame(
    Item_ID = c("A", "B"),
    Item_Label = c("Alpha", "Beta"),
    Best_Pct = c(25, 15),
    Worst_Pct = c(5, 20),
    BW_Score = c(0.5, -0.2),
    stringsAsFactors = FALSE
  )

  svg <- build_diverging_chart(count_data)

  expect_true(is.character(svg))
  expect_true(grepl("<svg", svg))
  expect_true(grepl("Alpha", svg))
})

test_that("build_turf_chart generates SVG", {
  skip_if(!exists("build_turf_chart", mode = "function"))

  curve <- data.frame(
    Portfolio_Size = c(0, 1, 2, 3),
    Reach_Pct = c(0, 40, 65, 80)
  )

  svg <- build_turf_chart(curve)

  expect_true(is.character(svg))
  expect_true(grepl("<svg", svg))
})

test_that("build_maxdiff_page generates complete HTML document", {
  skip_if(!exists("build_maxdiff_page", mode = "function"))

  html_data <- list(
    meta = list(
      project_name = "Test", brand_colour = "#1e3a5f", accent_colour = "#2aa198",
      method = "HB", generated = "2026-01-01", n_total = 100, n_items = 6
    ),
    summary = list(method_label = "HB", n_total = 100, n_items = 6, top_item = "Alpha",
                   callout = '<div class="md-callout md-callout-result">Test</div>'),
    preferences = list(scores = data.frame(
      Item_ID = "A", Item_Label = "Alpha", Utility = 1, SE = 0.1, Rescaled = 100, Rank = 1, Pref_Share = 50,
      stringsAsFactors = FALSE
    )),
    items = NULL,
    segments = NULL,
    turf = NULL,
    diagnostics = list(logit_fit = NULL, hb_diagnostics = NULL, n_total = 100, n_tasks = 12, n_items = 6,
                       callout = '<div class="md-callout">Diag</div>')
  )

  tables <- list(preference_scores = "<table></table>", diagnostics = "<table></table>")
  charts <- list()
  config <- list()

  page <- build_maxdiff_page(html_data, tables, charts, config)

  expect_true(grepl("<!DOCTYPE html>", page))
  expect_true(grepl("turas-report-type", page))
  expect_true(grepl("maxdiff", page))
  expect_true(grepl("</html>", page))
})

test_that("generate_maxdiff_html_report writes valid file", {
  skip_if(!exists("generate_maxdiff_html_report", mode = "function"))

  td <- generate_test_data()
  tmp_file <- tempfile(fileext = ".html")

  results <- list(
    count_scores = data.frame(
      Item_ID = td$items$Item_ID, Item_Label = td$items$Item_Label,
      Best_Pct = runif(td$n_items, 5, 30), Worst_Pct = runif(td$n_items, 5, 30),
      BW_Score = rnorm(td$n_items), stringsAsFactors = FALSE
    ),
    hb_results = list(
      population_utilities = data.frame(
        Item_ID = td$items$Item_ID, Item_Label = td$items$Item_Label,
        HB_Utility_Mean = td$true_utils, HB_Utility_SD = rep(0.3, td$n_items),
        stringsAsFactors = FALSE
      ),
      individual_utilities = td$individual_utils
    ),
    study_summary = list(n_respondents = td$n_resp, n_tasks = td$n_tasks, n_items = td$n_items)
  )

  config <- list(
    project_settings = list(Project_Name = "Test", Brand_Colour = "#1e3a5f", Accent_Colour = "#2aa198"),
    items = td$items,
    output_settings = list()
  )

  result <- generate_maxdiff_html_report(results, tmp_file, config)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp_file))

  content <- paste(readLines(tmp_file, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", content))
  expect_true(grepl("turas-report-type", content))

  unlink(tmp_file)
})
