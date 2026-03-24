# ==============================================================================
# TEST SUITE: Tracker Excel Output Writers
# ==============================================================================
# Tests for tracker_output.R, tracker_output_banners.R,
# and tracker_output_extended.R
# ==============================================================================

library(testthat)

context("Tracker Excel Output Writers")

# ==============================================================================
# SETUP
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source shared utilities
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

shared_formatting <- file.path(turas_root, "modules", "shared", "lib", "formatting_utils.R")
if (file.exists(shared_formatting)) source(shared_formatting)

shared_libs <- sort(list.files(file.path(turas_root, "modules", "shared", "lib"),
                               pattern = "[.]R$", full.names = TRUE))
for (f in shared_libs) {
  tryCatch(source(f), error = function(e) NULL)
}

# Source tracker dependencies in order
source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "output_formatting.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))

# Source the files under test
source(file.path(tracker_root, "lib", "tracker_output.R"))
source(file.path(tracker_root, "lib", "tracker_output_banners.R"))
source(file.path(tracker_root, "lib", "tracker_output_extended.R"))


# ==============================================================================
# HELPERS: Mock Data Builders
# ==============================================================================

make_mock_config <- function() {
  list(
    waves = data.frame(
      WaveID = c("W1", "W2"),
      WaveName = c("Wave 1", "Wave 2"),
      FieldworkStart = c("2025-01-01", "2025-04-01"),
      FieldworkEnd = c("2025-02-01", "2025-05-01"),
      DataFile = c("w1.csv", "w2.csv"),
      stringsAsFactors = FALSE
    ),
    config_path = file.path(tempdir(), "mock_config.xlsx"),
    settings = list(
      project_name = "TestProject",
      alpha = 0.05,
      minimum_base = 30,
      decimal_places_ratings = 1,
      show_significance = TRUE,
      decimal_separator = "."
    )
  )
}

make_mock_wave_data <- function() {
  list(
    W1 = data.frame(id = 1:100, Q1 = sample(1:5, 100, replace = TRUE)),
    W2 = data.frame(id = 1:110, Q1 = sample(1:5, 110, replace = TRUE))
  )
}

make_mock_wave_result <- function(mean_val, n, values = NULL) {
  result <- list(
    available = TRUE,
    mean = mean_val,
    n_unweighted = n,
    n_weighted = n,
    values = values
  )
  result
}

make_mock_mean_trend <- function() {
  list(
    Q1 = list(
      question_code = "Q1",
      question_text = "Overall satisfaction",
      metric_type = "mean",
      wave_results = list(
        W1 = make_mock_wave_result(3.5, 100, values = sample(1:5, 100, replace = TRUE)),
        W2 = make_mock_wave_result(3.8, 110, values = sample(1:5, 110, replace = TRUE))
      ),
      changes = list(
        W1_W2 = list(
          from_wave = "W1",
          to_wave = "W2",
          absolute_change = 0.3,
          percentage_change = 8.57
        )
      ),
      significance = list(
        W1_vs_W2 = list(
          p_value = 0.03,
          significant = TRUE,
          test_method = "t_test"
        )
      )
    )
  )
}

make_mock_nps_trend <- function() {
  list(
    Q_NPS = list(
      question_code = "Q_NPS",
      question_text = "How likely to recommend?",
      metric_type = "nps",
      wave_results = list(
        W1 = list(
          available = TRUE,
          nps = 25,
          promoters_pct = 40,
          passives_pct = 30,
          detractors_pct = 30,
          n_unweighted = 100
        ),
        W2 = list(
          available = TRUE,
          nps = 30,
          promoters_pct = 45,
          passives_pct = 25,
          detractors_pct = 30,
          n_unweighted = 110
        )
      ),
      changes = list(),
      significance = list()
    )
  )
}

make_mock_proportions_trend <- function() {
  list(
    Q_GENDER = list(
      question_code = "Q_GENDER",
      question_text = "What is your gender?",
      metric_type = "proportions",
      response_codes = c("Male", "Female", "Other"),
      wave_results = list(
        W1 = list(
          available = TRUE,
          proportions = list(Male = 48.5, Female = 46.2, Other = 5.3),
          n_unweighted = 100
        ),
        W2 = list(
          available = TRUE,
          proportions = list(Male = 50.1, Female = 44.8, Other = 5.1),
          n_unweighted = 110
        )
      ),
      changes = list(),
      significance = list()
    )
  )
}

make_mock_enhanced_trend <- function() {
  list(
    Q_RATING = list(
      question_code = "Q_RATING",
      question_text = "Rate our service",
      metric_type = "rating_enhanced",
      tracking_specs = c("mean", "top2_box"),
      wave_results = list(
        W1 = list(
          available = TRUE,
          metrics = list(mean = 3.5, top2_box = 42.0),
          n_unweighted = 100
        ),
        W2 = list(
          available = TRUE,
          metrics = list(mean = 3.8, top2_box = 48.0),
          n_unweighted = 110
        )
      ),
      changes = list(),
      significance = list()
    )
  )
}

make_mock_banner_results <- function() {
  base_result <- function(mean_val, n) {
    list(
      question_code = "Q1",
      question_text = "Overall satisfaction",
      metric_type = "mean",
      wave_results = list(
        W1 = make_mock_wave_result(mean_val, n),
        W2 = make_mock_wave_result(mean_val + 0.3, n + 10)
      ),
      changes = list(
        W1_W2 = list(
          from_wave = "W1",
          to_wave = "W2",
          from_value = mean_val,
          to_value = mean_val + 0.3,
          absolute_change = 0.3,
          percentage_change = 8.57
        )
      ),
      significance = list(
        W1_vs_W2 = list(p_value = 0.03, significant = TRUE, test_method = "t_test")
      )
    )
  }

  list(
    Q1 = list(
      Total = base_result(3.5, 100),
      Male = base_result(3.6, 50),
      Female = base_result(3.4, 50)
    )
  )
}

make_mock_multi_mention_trend <- function() {
  list(
    Q_BRAND = list(
      question_code = "Q_BRAND",
      question_text = "Which brands are you aware of?",
      metric_type = "multi_mention",
      tracked_columns = c("Brand_A", "Brand_B", "Brand_C"),
      wave_results = list(
        W1 = list(
          available = TRUE,
          mention_proportions = list(Brand_A = 65.0, Brand_B = 45.0, Brand_C = 30.0),
          additional_metrics = list(any_mention_pct = 92.0, count_mean = 2.1),
          n_unweighted = 100
        ),
        W2 = list(
          available = TRUE,
          mention_proportions = list(Brand_A = 68.0, Brand_B = 42.0, Brand_C = 33.0),
          additional_metrics = list(any_mention_pct = 94.0, count_mean = 2.3),
          n_unweighted = 110
        )
      ),
      changes = list(),
      significance = list()
    )
  )
}


# ==============================================================================
# TESTS: detect_banner_results()
# ==============================================================================

test_that("detect_banner_results returns FALSE for empty results", {
  expect_false(detect_banner_results(list()))
})

test_that("detect_banner_results returns FALSE for simple (non-banner) results", {
  simple <- make_mock_mean_trend()
  expect_false(detect_banner_results(simple))
})

test_that("detect_banner_results returns TRUE for banner results", {
  banner <- make_mock_banner_results()
  expect_true(detect_banner_results(banner))
})

test_that("detect_banner_results handles single-segment banner structure", {
  # Banner with only Total segment
  single_banner <- list(
    Q1 = list(
      Total = list(
        question_code = "Q1",
        question_text = "Test",
        metric_type = "mean",
        wave_results = list()
      )
    )
  )
  expect_true(detect_banner_results(single_banner))
})


# ==============================================================================
# TESTS: write_summary_sheet()
# ==============================================================================

test_that("write_summary_sheet creates Summary worksheet in workbook", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  wave_data <- make_mock_wave_data()
  trend_results <- make_mock_mean_trend()
  styles <- create_tracker_styles()

  write_summary_sheet(wb, config, wave_data, trend_results, styles)

  expect_true("Summary" %in% names(wb))
})

test_that("write_summary_sheet writes project name and wave info", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  wave_data <- make_mock_wave_data()
  trend_results <- make_mock_mean_trend()
  styles <- create_tracker_styles()

  write_summary_sheet(wb, config, wave_data, trend_results, styles)

  # Save to temp file and read back to verify content
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Summary", colNames = FALSE)
  # First row should contain the title

  expect_true(any(grepl("TRACKING ANALYSIS SUMMARY", unlist(df[1, ]), fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_metadata_sheet()
# ==============================================================================

test_that("write_metadata_sheet creates Metadata worksheet", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  wave_data <- make_mock_wave_data()
  styles <- create_tracker_styles()

  write_metadata_sheet(wb, config, wave_data, styles)

  expect_true("Metadata" %in% names(wb))
})

test_that("write_metadata_sheet includes key settings", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  wave_data <- make_mock_wave_data()
  styles <- create_tracker_styles()

  write_metadata_sheet(wb, config, wave_data, styles)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Metadata", colNames = FALSE)
  cell_values <- unlist(df)
  expect_true(any(grepl("project_name", cell_values, fixed = TRUE)))
  expect_true(any(grepl("alpha", cell_values, fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_trend_sheets() - Mean metric
# ==============================================================================

test_that("write_trend_sheets creates sheets for mean metric results", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend_results <- make_mock_mean_trend()

  write_trend_sheets(wb, trend_results, config, styles)

  expect_true("Q1" %in% names(wb))
})

test_that("write_trend_sheets writes mean values and sample sizes", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend_results <- make_mock_mean_trend()

  write_trend_sheets(wb, trend_results, config, styles)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Q1", colNames = FALSE)
  cell_values <- unlist(df)
  # Should contain "Mean" label and "Sample Size" label
  expect_true(any(grepl("Mean", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Sample Size", cell_values, fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_trend_sheets() - NPS metric
# ==============================================================================

test_that("write_trend_sheets creates sheet for NPS metric", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend_results <- make_mock_nps_trend()

  write_trend_sheets(wb, trend_results, config, styles)

  expect_true("Q_NPS" %in% names(wb))
})

test_that("write_nps_trend_table writes NPS metrics", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend_results <- make_mock_nps_trend()

  write_trend_sheets(wb, trend_results, config, styles)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Q_NPS", colNames = FALSE)
  cell_values <- unlist(df)
  expect_true(any(grepl("NPS Score", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Promoters", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Detractors", cell_values, fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_trend_sheets() - Proportions metric
# ==============================================================================

test_that("write_trend_sheets creates sheet for proportions metric", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend_results <- make_mock_proportions_trend()

  write_trend_sheets(wb, trend_results, config, styles)

  expect_true("Q_GENDER" %in% names(wb))
})

test_that("write_proportions_trend_table writes response codes", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend_results <- make_mock_proportions_trend()

  write_trend_sheets(wb, trend_results, config, styles)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Q_GENDER", colNames = FALSE)
  cell_values <- unlist(df)
  expect_true(any(grepl("Male", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Female", cell_values, fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_trend_sheets() - Enhanced rating metric
# ==============================================================================

test_that("write_trend_sheets creates sheet for enhanced rating metric", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend_results <- make_mock_enhanced_trend()

  write_trend_sheets(wb, trend_results, config, styles)

  expect_true("Q_RATING" %in% names(wb))
})

test_that("write_enhanced_rating_trend_table writes multiple metrics", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend_results <- make_mock_enhanced_trend()

  write_trend_sheets(wb, trend_results, config, styles)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Q_RATING", colNames = FALSE)
  cell_values <- unlist(df)
  expect_true(any(grepl("Mean", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Top 2 Box", cell_values, fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_tracker_output() (full orchestration)
# ==============================================================================

test_that("write_tracker_output creates valid Excel file for simple results", {
  config <- make_mock_config()
  wave_data <- make_mock_wave_data()
  trend_results <- make_mock_mean_trend()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result_path <- write_tracker_output(trend_results, config, wave_data, output_path = tmp)

  expect_true(file.exists(result_path))
  expect_equal(result_path, tmp)

  # Verify workbook has expected sheets
  wb <- openxlsx::loadWorkbook(tmp)
  sheet_names <- names(wb)
  expect_true("Summary" %in% sheet_names)
  expect_true("Metadata" %in% sheet_names)
  expect_true("Q1" %in% sheet_names)
})

test_that("write_tracker_output refuses invalid trend_results", {
  config <- make_mock_config()
  wave_data <- make_mock_wave_data()

  expect_error(
    write_tracker_output(list(), config, wave_data),
    regexp = "REFUSED|non-empty|invalid",
    ignore.case = TRUE
  )
})

test_that("write_tracker_output refuses invalid config", {
  wave_data <- make_mock_wave_data()
  trend_results <- make_mock_mean_trend()

  expect_error(
    write_tracker_output(trend_results, list(), wave_data),
    regexp = "REFUSED|invalid|waves",
    ignore.case = TRUE
  )
})


# ==============================================================================
# TESTS: write_trend_sheets_with_banners()
# ==============================================================================

test_that("write_trend_sheets_with_banners creates sheets with banner columns", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  banner_results <- make_mock_banner_results()

  write_trend_sheets_with_banners(wb, banner_results, config, styles)

  expect_true("Q1" %in% names(wb))
})

test_that("write_trend_sheets_with_banners writes segment column headers", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  banner_results <- make_mock_banner_results()

  write_trend_sheets_with_banners(wb, banner_results, config, styles)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Q1", colNames = FALSE)
  cell_values <- unlist(df)
  # Should contain segment-wave column headers
  expect_true(any(grepl("W1_Total", cell_values, fixed = TRUE)))
  expect_true(any(grepl("W2_Male", cell_values, fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_change_summary_sheet()
# ==============================================================================

test_that("write_change_summary_sheet creates Change_Summary worksheet", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  banner_results <- make_mock_banner_results()

  write_change_summary_sheet(wb, banner_results, config, styles)

  expect_true("Change_Summary" %in% names(wb))
})

test_that("write_change_summary_sheet writes baseline vs latest comparison", {
  wb <- openxlsx::createWorkbook()
  config <- make_mock_config()
  styles <- create_tracker_styles()
  banner_results <- make_mock_banner_results()

  write_change_summary_sheet(wb, banner_results, config, styles)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Change_Summary", colNames = FALSE)
  cell_values <- unlist(df)
  expect_true(any(grepl("CHANGE SUMMARY", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Question", cell_values, fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_distribution_table()
# ==============================================================================

test_that("write_distribution_table writes distribution for mean metric type", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "TestSheet")
  config <- make_mock_config()
  styles <- create_tracker_styles()

  result <- list(
    metric_type = "mean",
    wave_results = list(
      W1 = list(available = TRUE, values = c(1, 2, 3, 4, 5, 3, 4, 5, 3, 4)),
      W2 = list(available = TRUE, values = c(2, 3, 4, 5, 5, 4, 4, 5, 3, 3))
    )
  )

  end_row <- write_distribution_table(wb, "TestSheet", result, c("W1", "W2"), config, styles, 1)

  expect_true(end_row > 1)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "TestSheet", colNames = FALSE)
  cell_values <- unlist(df)
  expect_true(any(grepl("Response Distribution", cell_values, fixed = TRUE)))
})

test_that("write_distribution_table returns start_row for non-mean types", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "TestSheet")
  config <- make_mock_config()
  styles <- create_tracker_styles()

  result <- list(metric_type = "proportions")

  end_row <- write_distribution_table(wb, "TestSheet", result, c("W1", "W2"), config, styles, 5)
  expect_equal(end_row, 5)
})


# ==============================================================================
# TESTS: write_multi_mention_trend_table()
# ==============================================================================

test_that("write_multi_mention_trend_table writes mention proportions", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Q_BRAND")
  config <- make_mock_config()
  styles <- create_tracker_styles()
  trend <- make_mock_multi_mention_trend()

  end_row <- write_multi_mention_trend_table(
    wb, "Q_BRAND", trend$Q_BRAND, c("W1", "W2"), config, styles, 1
  )

  expect_true(end_row > 1)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Q_BRAND", colNames = FALSE)
  cell_values <- unlist(df)
  expect_true(any(grepl("Brand_A", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Brand_B", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Mentioning Any", cell_values, fixed = TRUE)))
  expect_true(any(grepl("Mean # of Mentions", cell_values, fixed = TRUE)))
})


# ==============================================================================
# TESTS: write_wave_history_output() and helpers
# ==============================================================================

test_that("extract_wave_history_metrics returns correct metrics for mean type", {
  result <- list(metric_type = "mean")
  metrics <- extract_wave_history_metrics(result)

  expect_equal(length(metrics), 1)
  expect_equal(metrics[[1]]$metric_key, "mean")
  expect_equal(metrics[[1]]$label, "Mean")
})

test_that("extract_wave_history_metrics returns correct metrics for NPS", {
  result <- list(metric_type = "nps")
  metrics <- extract_wave_history_metrics(result)

  expect_equal(length(metrics), 1)
  expect_equal(metrics[[1]]$metric_key, "nps")
  expect_equal(metrics[[1]]$label, "NPS")
})

test_that("extract_wave_history_metrics handles enhanced rating with specs", {
  result <- list(
    metric_type = "rating_enhanced",
    tracking_specs = c("mean", "top2_box", "distribution")
  )
  metrics <- extract_wave_history_metrics(result)

  # Should exclude distribution
  expect_equal(length(metrics), 2)
  expect_equal(metrics[[1]]$metric_key, "mean")
  expect_equal(metrics[[2]]$metric_key, "top2_box")
})

test_that("extract_wave_history_metrics handles proportions with response codes", {
  result <- list(
    metric_type = "proportions",
    response_codes = c("Yes", "No", "Maybe")
  )
  metrics <- extract_wave_history_metrics(result)

  expect_equal(length(metrics), 3)
  expect_equal(metrics[[1]]$metric_key, "proportion:Yes")
  expect_equal(metrics[[2]]$label, "% No")
})

test_that("extract_metric_value_by_key retrieves mean from wave result", {
  wave_result <- list(available = TRUE, mean = 3.5)
  val <- extract_metric_value_by_key(wave_result, "mean", "mean")
  expect_equal(val, 3.5)
})

test_that("extract_metric_value_by_key retrieves nps from wave result", {
  wave_result <- list(available = TRUE, nps = 25)
  val <- extract_metric_value_by_key(wave_result, "nps", "nps")
  expect_equal(val, 25)
})

test_that("extract_metric_value_by_key retrieves proportion from wave result", {
  wave_result <- list(
    available = TRUE,
    proportions = list(Yes = 65.0, No = 35.0)
  )
  val <- extract_metric_value_by_key(wave_result, "proportion:Yes", "proportions")
  expect_equal(val, 65.0)
})

test_that("extract_metric_value_by_key retrieves mention from wave result", {
  wave_result <- list(
    available = TRUE,
    mention_proportions = list(Brand_A = 68.0)
  )
  val <- extract_metric_value_by_key(wave_result, "mention:Brand_A", "multi_mention")
  expect_equal(val, 68.0)
})

test_that("extract_metric_value_by_key returns NA or NULL for missing metric", {
  wave_result <- list(available = TRUE, mean = 3.5)
  # When metric_key is "nps" but wave_result has no $nps, it returns NULL
  val <- extract_metric_value_by_key(wave_result, "nps", "mean")
  expect_true(is.null(val) || is.na(val))

  # When metric_key is an unrecognised prefix, it falls through to NA_real_
  val2 <- extract_metric_value_by_key(wave_result, "unknown_key", "mean")
  expect_true(is.na(val2))
})

test_that("write_wave_history_output creates valid Excel file", {
  config <- make_mock_config()
  wave_data <- make_mock_wave_data()
  trend_results <- make_mock_mean_trend()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result_path <- write_wave_history_output(trend_results, config, wave_data, output_path = tmp)

  expect_true(file.exists(result_path))
  wb <- openxlsx::loadWorkbook(tmp)
  expect_true("Total" %in% names(wb))
})


# ==============================================================================
# TESTS: Full banner orchestration via write_tracker_output()
# ==============================================================================

test_that("write_tracker_output handles banner results end-to-end", {
  config <- make_mock_config()
  wave_data <- make_mock_wave_data()
  banner_results <- make_mock_banner_results()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result_path <- write_tracker_output(banner_results, config, wave_data, output_path = tmp)

  expect_true(file.exists(result_path))
  wb <- openxlsx::loadWorkbook(tmp)
  sheet_names <- names(wb)
  expect_true("Summary" %in% sheet_names)
  expect_true("Q1" %in% sheet_names)
  expect_true("Change_Summary" %in% sheet_names)
  expect_true("Metadata" %in% sheet_names)
})
