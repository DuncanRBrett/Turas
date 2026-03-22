# ==============================================================================
# TEST SUITE: Configuration Validation
# ==============================================================================
# Tests for config loading, parsing, and validation functions.
#
# Functions tested from tracker_config_loader.R:
#   - load_tracking_config()
#   - parse_settings_to_list()
#   - get_setting()
#   - get_baseline_wave()
#   - validate_tracking_config()
#
# Functions tested from 00_guard.R:
#   - validate_tracker_config()
#
# ==============================================================================

library(testthat)

context("Configuration Validation")

# ==============================================================================
# SETUP: Source required modules
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source shared TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Source tracker modules in dependency order
guard_path <- file.path(tracker_root, "lib", "00_guard.R")
if (file.exists(guard_path)) source(guard_path)

config_loader_path <- file.path(tracker_root, "lib", "tracker_config_loader.R")
if (file.exists(config_loader_path)) source(config_loader_path)

# Source preflight validators (for check_tracking_specs_valid tests)
preflight_path <- file.path(tracker_root, "lib", "validation", "preflight_validators.R")
if (file.exists(preflight_path)) source(preflight_path)


# ==============================================================================
# HELPER: Create mock config objects for testing
# ==============================================================================

create_test_config <- function(waves = NULL, settings = NULL, banner = NULL,
                               tracked_questions = NULL) {
  if (is.null(waves)) {
    waves <- data.frame(
      WaveID = c("W1", "W2", "W3"),
      WaveName = c("Jan 2024", "Apr 2024", "Jul 2024"),
      DataFile = c("wave1.csv", "wave2.csv", "wave3.csv"),
      FieldworkStart = as.Date(c("2024-01-01", "2024-04-01", "2024-07-01")),
      FieldworkEnd = as.Date(c("2024-01-31", "2024-04-30", "2024-07-31")),
      stringsAsFactors = FALSE
    )
  }

  if (is.null(tracked_questions)) {
    tracked_questions <- data.frame(
      QuestionCode = c("Q_SAT", "Q_NPS", "Q_AWARE"),
      MetricLabel = c("Satisfaction", "NPS Score", "Awareness"),
      TrackingSpecs = c("mean,top2_box", "nps_score", "category:Yes"),
      Section = c("Brand Health", "Brand Health", "Key Metrics"),
      SortOrder = c(1, 2, 3),
      stringsAsFactors = FALSE
    )
  }

  if (is.null(settings)) {
    settings <- list(
      project_name = "Test Project",
      baseline_wave = "W1",
      decimal_places_ratings = 1,
      show_significance = TRUE
    )
  }

  if (is.null(banner)) {
    banner <- data.frame(
      BreakVariable = c("Total", "Gender", "Gender"),
      BreakLabel = c("Overall", "Male", "Female"),
      stringsAsFactors = FALSE
    )
  }

  list(
    waves = waves,
    settings = settings,
    banner = banner,
    tracked_questions = tracked_questions,
    config_path = "/mock/path/config.xlsx"
  )
}


# ==============================================================================
# TESTS: Duplicate QuestionCode detection
# ==============================================================================

test_that("load_tracking_config refuses duplicate QuestionCodes", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_dup_config.xlsx")

  wb <- openxlsx::createWorkbook()

  # Waves sheet
  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1", "W2"),
    WaveName = c("Wave 1", "Wave 2"),
    DataFile = c("w1.csv", "w2.csv"),
    FieldworkStart = c("2024-01-01", "2024-04-01"),
    FieldworkEnd = c("2024-01-31", "2024-04-30"),
    stringsAsFactors = FALSE
  ))

  # Settings sheet
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("project_name"),
    Value = c("Test"),
    stringsAsFactors = FALSE
  ))

  # Banner sheet
  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = "Total",
    BreakLabel = "Overall",
    stringsAsFactors = FALSE
  ))

  # TrackedQuestions with DUPLICATE QuestionCode
  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q_SAT", "Q_NPS", "Q_SAT"),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  # tracker_refuse throws a turas_refusal condition
  expect_error(
    load_tracking_config(config_path),
    class = "turas_refusal"
  )

  file.remove(config_path)
})


# ==============================================================================
# TESTS: TrackingSpecs format validation
# ==============================================================================

test_that("TrackingSpecs defaults to NA when column is missing", {
  tq <- data.frame(
    QuestionCode = c("Q1", "Q2"),
    stringsAsFactors = FALSE
  )

  # Simulate what load_tracking_config does
  if (!"TrackingSpecs" %in% names(tq)) tq$TrackingSpecs <- NA_character_

  expect_true("TrackingSpecs" %in% names(tq))
  expect_true(all(is.na(tq$TrackingSpecs)))
})

test_that("TrackingSpecs preserves valid specs", {
  tq <- data.frame(
    QuestionCode = c("Q_SAT", "Q_NPS"),
    TrackingSpecs = c("mean,top2_box", "nps_score,promoters_pct"),
    stringsAsFactors = FALSE
  )
  expect_equal(tq$TrackingSpecs[1], "mean,top2_box")
  expect_equal(tq$TrackingSpecs[2], "nps_score,promoters_pct")
})


# ==============================================================================
# TESTS: Config loader TrackingSpecs inline validation (comma-split, patterns)
# ==============================================================================

test_that("config loader TrackingSpecs validation: comma-separated specs do not warn", {
  skip_if_not(exists("load_tracking_config", mode = "function"),
              "load_tracking_config not loaded")
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_specs_config.xlsx")

  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = "W1", WaveName = "Wave 1", DataFile = "w1.csv",
    FieldworkStart = "2024-01-01", FieldworkEnd = "2024-01-31",
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q1", "Q2", "Q3", "Q4"),
    TrackingSpecs = c("mean,top2_box", "nps_score,promoters_pct",
                      "box:Agree=Top Box", "range:4-5,category:Yes"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = "Gender", BreakLabel = "Gender",
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("project_name"), Value = c("Test"),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  # Should not produce any "Unrecognized TrackingSpecs" warning
  output <- capture.output({
    config <- load_tracking_config(config_path)
  })
  warning_lines <- grep("Unrecognized TrackingSpecs", output, value = TRUE)
  expect_equal(length(warning_lines), 0,
               info = paste("Unexpected warnings:", paste(warning_lines, collapse = "\n")))

  unlink(config_path)
})

test_that("config loader TrackingSpecs validation: invalid specs produce warning", {
  skip_if_not(exists("load_tracking_config", mode = "function"),
              "load_tracking_config not loaded")
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_specs_invalid_config.xlsx")

  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = "W1", WaveName = "Wave 1", DataFile = "w1.csv",
    FieldworkStart = "2024-01-01", FieldworkEnd = "2024-01-31",
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q1"),
    TrackingSpecs = c("totally_bogus_spec"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = "Gender", BreakLabel = "Gender",
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("project_name"), Value = c("Test"),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  output <- capture.output({
    config <- load_tracking_config(config_path)
  })
  warning_lines <- grep("Unrecognized TrackingSpecs", output, value = TRUE)
  expect_true(length(warning_lines) > 0,
              info = "Should warn about invalid TrackingSpecs")

  unlink(config_path)
})


# ==============================================================================
# TESTS: Preflight check_tracking_specs_valid (comma-split, patterns, =Label)
# ==============================================================================

test_that("preflight check_tracking_specs_valid: accepts all valid spec types", {
  skip_if_not(exists("check_tracking_specs_valid", mode = "function"),
              "check_tracking_specs_valid not loaded")
  skip_if_not(exists("log_preflight_issue", mode = "function"),
              "log_preflight_issue not loaded")

  # Use the actual column structure from log_preflight_issue
  error_log <- data.frame(Timestamp = character(0), Component = character(0),
                          Issue_Type = character(0), Description = character(0),
                          QuestionCode = character(0), Severity = character(0),
                          stringsAsFactors = FALSE)

  tracked_df <- data.frame(
    QuestionCode = c("Q1", "Q2", "Q3", "Q4", "Q5", "Q6"),
    TrackingSpecs = c(
      "mean,top2_box,bottom_box",
      "nps_score,promoters_pct,detractors_pct",
      "distribution,all,top3",
      "auto,any,count_mean,count_distribution",
      "box:Agree=Top Box,range:4-5=High",
      "category:Yes,option:Brand_A"
    ),
    stringsAsFactors = FALSE
  )

  result <- check_tracking_specs_valid(tracked_df, error_log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0,
               info = paste("Unexpected errors:", paste(errors$Description, collapse = "\n")))
})

test_that("preflight check_tracking_specs_valid: rejects invalid specs", {
  skip_if_not(exists("check_tracking_specs_valid", mode = "function"),
              "check_tracking_specs_valid not loaded")
  skip_if_not(exists("log_preflight_issue", mode = "function"),
              "log_preflight_issue not loaded")

  error_log <- data.frame(Timestamp = character(0), Component = character(0),
                          Issue_Type = character(0), Description = character(0),
                          QuestionCode = character(0), Severity = character(0),
                          stringsAsFactors = FALSE)

  tracked_df <- data.frame(
    QuestionCode = c("Q1"),
    TrackingSpecs = c("mean,pct_agree,bogus"),
    stringsAsFactors = FALSE
  )

  result <- check_tracking_specs_valid(tracked_df, error_log)
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0, info = "Should flag pct_agree and bogus as invalid")
  expect_true(grepl("pct_agree", errors$Description[1]))
  expect_true(grepl("bogus", errors$Description[1]))
})

test_that("preflight check_tracking_specs_valid: strips =Label before validation", {
  skip_if_not(exists("check_tracking_specs_valid", mode = "function"),
              "check_tracking_specs_valid not loaded")
  skip_if_not(exists("log_preflight_issue", mode = "function"),
              "log_preflight_issue not loaded")

  error_log <- data.frame(Timestamp = character(0), Component = character(0),
                          Issue_Type = character(0), Description = character(0),
                          QuestionCode = character(0), Severity = character(0),
                          stringsAsFactors = FALSE)

  tracked_df <- data.frame(
    QuestionCode = c("Q1"),
    TrackingSpecs = c("mean=Average,top2_box=Agree,box:Agree=Top Box"),
    stringsAsFactors = FALSE
  )

  result <- check_tracking_specs_valid(tracked_df, error_log)
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0,
               info = paste("Labels should be stripped:", paste(errors$Description, collapse = "\n")))
})


# ==============================================================================
# TESTS: known_metadata_cols includes ResponseScale and ScalePoints
# ==============================================================================

test_that("known_metadata_cols: ResponseScale and ScalePoints excluded from wave detection", {
  # Test the filtering logic directly — these columns should be in known_metadata_cols
  # so they are excluded when detecting wave columns from the QuestionMap sheet
  known_metadata_cols <- c("QuestionCode", "QuestionText", "QuestionType", "SourceQuestions",
                           "TrackingSpecs", "ResponseScale", "ScalePoints")

  all_cols <- c("QuestionCode", "QuestionText", "QuestionType", "W1", "W2",
                "ResponseScale", "ScalePoints", "TrackingSpecs")
  potential_wave_cols <- setdiff(all_cols, known_metadata_cols)

  expect_true("W1" %in% potential_wave_cols)
  expect_true("W2" %in% potential_wave_cols)
  expect_false("ResponseScale" %in% potential_wave_cols)
  expect_false("ScalePoints" %in% potential_wave_cols)
  expect_equal(length(potential_wave_cols), 2)
})


# ==============================================================================
# TESTS: Date range validation (FieldworkStart > FieldworkEnd warning)
# ==============================================================================

test_that("load_tracking_config warns when FieldworkStart after FieldworkEnd", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_date_config.xlsx")

  wb <- openxlsx::createWorkbook()

  # Waves sheet with swapped dates
  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1", "W2"),
    WaveName = c("Wave 1", "Wave 2"),
    DataFile = c("w1.csv", "w2.csv"),
    FieldworkStart = c("2024-01-31", "2024-04-01"),
    FieldworkEnd = c("2024-01-01", "2024-04-30"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = "project_name", Value = "Test", stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = "Total", BreakLabel = "Overall", stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q1"), stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  # Should produce a warning about swapped dates
  output <- capture.output(
    config <- load_tracking_config(config_path),
    type = "output"
  )

  expect_true(any(grepl("FieldworkStart.*after.*FieldworkEnd|Dates may be swapped", output)))

  file.remove(config_path)
})


# ==============================================================================
# TESTS: Missing required columns
# ==============================================================================

test_that("load_tracking_config refuses when Waves sheet missing required columns", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_missing_cols.xlsx")

  wb <- openxlsx::createWorkbook()

  # Waves sheet missing DataFile
  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1"),
    WaveName = c("Wave 1"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = "project_name", Value = "Test", stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = "Total", BreakLabel = "Overall", stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q1"), stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  # Should throw a turas_refusal for missing wave columns
  expect_error(
    load_tracking_config(config_path),
    class = "turas_refusal"
  )

  file.remove(config_path)
})

test_that("load_tracking_config refuses when TrackedQuestions missing QuestionCode column", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_no_qcode.xlsx")

  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1", "W2"),
    WaveName = c("Wave 1", "Wave 2"),
    DataFile = c("w1.csv", "w2.csv"),
    FieldworkStart = c("2024-01-01", "2024-04-01"),
    FieldworkEnd = c("2024-01-31", "2024-04-30"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = "project_name", Value = "Test", stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = "Total", BreakLabel = "Overall", stringsAsFactors = FALSE
  ))

  # TrackedQuestions without QuestionCode column
  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    MetricLabel = c("Satisfaction"),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  expect_error(
    load_tracking_config(config_path),
    class = "turas_refusal"
  )

  file.remove(config_path)
})


# ==============================================================================
# TESTS: Empty config sheets
# ==============================================================================

test_that("validate_tracking_config refuses empty banner", {
  config <- create_test_config(
    banner = data.frame(
      BreakVariable = character(0),
      BreakLabel = character(0),
      stringsAsFactors = FALSE
    )
  )

  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT"),
    QuestionType = c("Rating"),
    W1 = c("Q10"),
    W2 = c("Q11"),
    stringsAsFactors = FALSE
  )

  expect_error(
    validate_tracking_config(config, question_mapping),
    class = "turas_refusal"
  )
})


# ==============================================================================
# TESTS: SortOrder with non-numeric values
# ==============================================================================

test_that("SortOrder with non-numeric values falls back to row order", {
  tq <- data.frame(
    QuestionCode = c("Q1", "Q2", "Q3", "Q4"),
    SortOrder = c("1", "abc", "3", ""),
    stringsAsFactors = FALSE
  )

  # Simulate SortOrder processing from load_tracking_config
  non_numeric <- !grepl("^[0-9]+$", as.character(tq$SortOrder))
  has_non_numeric <- any(non_numeric, na.rm = TRUE)

  tq$SortOrder <- suppressWarnings(as.numeric(tq$SortOrder))
  na_rows <- is.na(tq$SortOrder)
  if (any(na_rows)) {
    tq$SortOrder[na_rows] <- which(na_rows)
  }

  expect_true(has_non_numeric)
  expect_equal(tq$SortOrder, c(1, 2, 3, 4))
})

test_that("SortOrder with all numeric values works correctly", {
  tq <- data.frame(
    QuestionCode = c("Q1", "Q2", "Q3"),
    SortOrder = c("3", "1", "2"),
    stringsAsFactors = FALSE
  )

  tq$SortOrder <- suppressWarnings(as.numeric(tq$SortOrder))
  expect_equal(tq$SortOrder, c(3, 1, 2))
})

test_that("SortOrder defaults to row order when column absent", {
  tq <- data.frame(
    QuestionCode = c("Q1", "Q2", "Q3"),
    stringsAsFactors = FALSE
  )

  if (!"SortOrder" %in% names(tq)) {
    tq$SortOrder <- seq_len(nrow(tq))
  }

  expect_equal(tq$SortOrder, c(1, 2, 3))
})


# ==============================================================================
# TESTS: MetricLabel defaulting to QuestionCode when blank
# ==============================================================================

test_that("MetricLabel defaults to NA when column is missing", {
  tq <- data.frame(
    QuestionCode = c("Q1", "Q2"),
    stringsAsFactors = FALSE
  )

  if (!"MetricLabel" %in% names(tq)) tq$MetricLabel <- NA_character_

  expect_true(all(is.na(tq$MetricLabel)))
})

test_that("MetricLabel preserves values when present", {
  tq <- data.frame(
    QuestionCode = c("Q1", "Q2"),
    MetricLabel = c("Satisfaction", ""),
    stringsAsFactors = FALSE
  )

  expect_equal(tq$MetricLabel[1], "Satisfaction")
  expect_equal(tq$MetricLabel[2], "")
})


# ==============================================================================
# TESTS: Banner duplicate detection
# ==============================================================================

test_that("load_tracking_config warns on duplicate banner entries", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_dup_banner.xlsx")

  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1", "W2"),
    WaveName = c("Wave 1", "Wave 2"),
    DataFile = c("w1.csv", "w2.csv"),
    FieldworkStart = c("2024-01-01", "2024-04-01"),
    FieldworkEnd = c("2024-01-31", "2024-04-30"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = "project_name", Value = "Test", stringsAsFactors = FALSE
  ))

  # Banner with duplicate entries
  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = c("Total", "Gender", "Gender", "Gender"),
    BreakLabel = c("Overall", "Male", "Female", "Male"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q1"), stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  output <- capture.output(
    config <- load_tracking_config(config_path),
    type = "output"
  )

  expect_true(any(grepl("Duplicate Banner", output)))

  file.remove(config_path)
})


# ==============================================================================
# TESTS: Settings parsing (boolean coercion, numeric coercion)
# ==============================================================================

test_that("parse_settings_to_list converts Y/N to logical", {
  settings_df <- data.frame(
    Setting = c("show_significance", "html_report", "feature_off"),
    Value = c("Y", "N", "Y"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_true(result$show_significance)
  expect_false(result$html_report)
  expect_true(result$feature_off)
})

test_that("parse_settings_to_list converts numeric strings to numbers", {
  settings_df <- data.frame(
    Setting = c("decimal_places_ratings", "alpha", "minimum_base"),
    Value = c("1", "0.05", "30"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_equal(result$decimal_places_ratings, 1)
  expect_equal(result$alpha, 0.05)
  expect_equal(result$minimum_base, 30)
})

test_that("parse_settings_to_list preserves string values", {
  settings_df <- data.frame(
    Setting = c("project_name", "brand_colour"),
    Value = c("My Project", "#323367"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_equal(result$project_name, "My Project")
  expect_equal(result$brand_colour, "#323367")
})

test_that("parse_settings_to_list handles SettingName column (legacy format)", {
  settings_df <- data.frame(
    SettingName = c("project_name"),
    Value = c("Legacy Project"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_equal(result$project_name, "Legacy Project")
})

test_that("parse_settings_to_list refuses missing Setting and SettingName columns", {
  settings_df <- data.frame(
    Name = c("project_name"),
    Value = c("Test"),
    stringsAsFactors = FALSE
  )

  expect_error(
    parse_settings_to_list(settings_df),
    class = "turas_refusal"
  )
})

test_that("parse_settings_to_list refuses missing Value column", {
  settings_df <- data.frame(
    Setting = c("project_name"),
    Data = c("Test"),
    stringsAsFactors = FALSE
  )

  expect_error(
    parse_settings_to_list(settings_df),
    class = "turas_refusal"
  )
})

test_that("parse_settings_to_list handles NA values", {
  settings_df <- data.frame(
    Setting = c("project_name", "weight_variable"),
    Value = c("Test", NA),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)

  expect_equal(result$project_name, "Test")
  expect_true(is.na(result$weight_variable))
})

test_that("parse_settings_to_list handles lowercase y/n", {
  settings_df <- data.frame(
    Setting = c("show_significance"),
    Value = c("y"),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)
  expect_true(result$show_significance)
})


# ==============================================================================
# TESTS: get_setting() with various inputs
# ==============================================================================

test_that("get_setting returns setting value when present", {
  config <- create_test_config()
  result <- get_setting(config, "project_name", default = "Fallback")
  expect_equal(result, "Test Project")
})

test_that("get_setting returns default when setting not present", {
  config <- create_test_config(settings = list(project_name = "Test"))
  result <- get_setting(config, "nonexistent_setting", default = "default_value")
  expect_equal(result, "default_value")
})

test_that("get_setting returns default when setting is NA", {
  config <- create_test_config(settings = list(project_name = "Test", weight_variable = NA))
  result <- get_setting(config, "weight_variable", default = "fallback_weight")
  expect_equal(result, "fallback_weight")
})

test_that("get_setting returns default when setting is empty string", {
  config <- create_test_config(settings = list(project_name = "Test", output_dir = ""))
  result <- get_setting(config, "output_dir", default = "/tmp")
  expect_equal(result, "/tmp")
})

test_that("get_setting returns default when setting is whitespace only", {
  config <- create_test_config(settings = list(project_name = "Test", output_dir = "   "))
  result <- get_setting(config, "output_dir", default = "/tmp")
  expect_equal(result, "/tmp")
})

test_that("get_setting returns NULL as default by default", {
  config <- create_test_config(settings = list(project_name = "Test"))
  result <- get_setting(config, "nonexistent_setting")
  expect_null(result)
})

test_that("get_setting works with NULL config$settings", {
  config <- list(settings = NULL)
  result <- get_setting(config, "project_name", default = "fallback")
  expect_equal(result, "fallback")
})

test_that("get_setting returns numeric setting without conversion", {
  config <- create_test_config(settings = list(decimal_places_ratings = 2))
  result <- get_setting(config, "decimal_places_ratings", default = 1)
  expect_equal(result, 2)
})

test_that("get_setting returns logical setting correctly", {
  config <- create_test_config(settings = list(show_significance = TRUE))
  result <- get_setting(config, "show_significance", default = FALSE)
  expect_true(result)
})


# ==============================================================================
# TESTS: validate_tracker_config (from 00_guard.R)
# ==============================================================================

test_that("validate_tracker_config passes with valid config", {
  config <- create_test_config()
  result <- validate_tracker_config(config)
  expect_true(result)
})

test_that("validate_tracker_config refuses non-list config", {
  expect_error(
    validate_tracker_config("not a list"),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_config refuses when waves section missing", {
  config <- list(
    settings = list(project_name = "Test"),
    tracked_questions = data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  )

  expect_error(
    validate_tracker_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_config refuses when tracked_questions section missing", {
  config <- list(
    waves = data.frame(
      WaveID = "W1", WaveName = "Wave 1", DataFile = "w1.csv",
      stringsAsFactors = FALSE
    ),
    settings = list(project_name = "Test")
  )

  expect_error(
    validate_tracker_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_config refuses when QuestionCode column missing", {
  config <- list(
    waves = data.frame(
      WaveID = "W1", WaveName = "Wave 1", DataFile = "w1.csv",
      stringsAsFactors = FALSE
    ),
    tracked_questions = data.frame(MetricLabel = "Satisfaction", stringsAsFactors = FALSE),
    settings = list(project_name = "Test")
  )

  expect_error(
    validate_tracker_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_config refuses when waves missing required columns", {
  config <- list(
    waves = data.frame(WaveID = "W1", stringsAsFactors = FALSE),
    tracked_questions = data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE),
    settings = list(project_name = "Test")
  )

  expect_error(
    validate_tracker_config(config),
    class = "turas_refusal"
  )
})


# ==============================================================================
# TESTS: validate_tracking_config (from tracker_config_loader.R)
# ==============================================================================

test_that("validate_tracking_config passes with valid config and mapping", {
  config <- create_test_config()

  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT", "Q_NPS", "Q_AWARE"),
    QuestionText = c("How satisfied?", "Recommend?", "Are you aware?"),
    QuestionType = c("Rating", "NPS", "Single_Response"),
    W1 = c("Q10", "Q15", "Q20"),
    W2 = c("Q11", "Q15", "Q20"),
    W3 = c("Q12", "Q15", "Q20"),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- validate_tracking_config(config, question_mapping),
    type = "message"
  )

  expect_true(result)
})

test_that("validate_tracking_config refuses duplicate WaveIDs", {
  config <- create_test_config(
    waves = data.frame(
      WaveID = c("W1", "W1", "W2"),
      WaveName = c("Wave 1a", "Wave 1b", "Wave 2"),
      DataFile = c("w1a.csv", "w1b.csv", "w2.csv"),
      FieldworkStart = as.Date(c("2024-01-01", "2024-02-01", "2024-04-01")),
      FieldworkEnd = as.Date(c("2024-01-31", "2024-02-28", "2024-04-30")),
      stringsAsFactors = FALSE
    )
  )

  expect_error(
    validate_tracking_config(config, NULL),
    class = "turas_refusal"
  )
})

test_that("validate_tracking_config warns on unmapped tracked questions", {
  config <- create_test_config()

  # Mapping only has Q_SAT, missing Q_NPS and Q_AWARE
  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT"),
    QuestionText = c("How satisfied?"),
    QuestionType = c("Rating"),
    W1 = c("Q10"),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- validate_tracking_config(config, question_mapping),
    type = "output"
  )

  expect_true(any(grepl("not found in question mapping", output)))
})


# ==============================================================================
# TESTS: Config file not found
# ==============================================================================

test_that("load_tracking_config refuses when file does not exist", {
  expect_error(
    load_tracking_config("/nonexistent/path/config.xlsx"),
    class = "turas_refusal"
  )
})


# ==============================================================================
# TESTS: Full config load from valid Excel file
# ==============================================================================

test_that("load_tracking_config loads valid config correctly", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_valid_config.xlsx")

  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1", "W2"),
    WaveName = c("Wave 1", "Wave 2"),
    DataFile = c("w1.csv", "w2.csv"),
    FieldworkStart = c("2024-01-01", "2024-04-01"),
    FieldworkEnd = c("2024-01-31", "2024-04-30"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("project_name", "show_significance", "decimal_places_ratings"),
    Value = c("Test Project", "Y", "2"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = c("Total", "Gender"),
    BreakLabel = c("Overall", "Male"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q_SAT", "Q_NPS"),
    MetricLabel = c("Satisfaction", "NPS"),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  config <- load_tracking_config(config_path)

  expect_true(is.list(config))
  expect_equal(nrow(config$waves), 2)
  expect_equal(nrow(config$tracked_questions), 2)
  expect_equal(nrow(config$banner), 2)
  expect_equal(config$settings$project_name, "Test Project")
  expect_true(config$settings$show_significance)
  expect_equal(config$settings$decimal_places_ratings, 2)
  expect_true("TrackingSpecs" %in% names(config$tracked_questions))
  expect_true("Section" %in% names(config$tracked_questions))
  expect_true("SortOrder" %in% names(config$tracked_questions))

  file.remove(config_path)
})


# ==============================================================================
# TESTS: Date coercion formats
# ==============================================================================

test_that("load_tracking_config handles YYYY-MM-DD date format", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_date_fmt.xlsx")

  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1"),
    WaveName = c("Wave 1"),
    DataFile = c("w1.csv"),
    FieldworkStart = c("2024-01-15"),
    FieldworkEnd = c("2024-02-15"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = "project_name", Value = "Test", stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = "Total", BreakLabel = "Overall", stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q1"), stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  config <- load_tracking_config(config_path)
  expect_s3_class(config$waves$FieldworkStart, "Date")

  file.remove(config_path)
})


# ==============================================================================
# TESTS: Section defaults
# ==============================================================================

test_that("Section column defaults to NA when missing", {
  tq <- data.frame(
    QuestionCode = c("Q1", "Q2"),
    stringsAsFactors = FALSE
  )

  if (!"Section" %in% names(tq)) tq$Section <- NA_character_

  expect_true("Section" %in% names(tq))
  expect_true(all(is.na(tq$Section)))
})


# ==============================================================================
# TESTS: Config missing Settings sheet columns
# ==============================================================================

test_that("parse_settings_to_list handles empty settings dataframe", {
  settings_df <- data.frame(
    Setting = character(0),
    Value = character(0),
    stringsAsFactors = FALSE
  )

  result <- parse_settings_to_list(settings_df)
  expect_true(is.list(result))
  expect_equal(length(result), 0)
})


# ==============================================================================
# TESTS: get_baseline_wave
# ==============================================================================

test_that("get_baseline_wave returns setting when specified", {
  config <- create_test_config(settings = list(baseline_wave = "W2"))
  expect_equal(get_baseline_wave(config), "W2")
})

test_that("get_baseline_wave defaults to first wave when not specified", {
  config <- create_test_config(settings = list(project_name = "Test"))
  expect_equal(get_baseline_wave(config), "W1")
})

test_that("get_baseline_wave handles NA setting", {
  config <- create_test_config(settings = list(baseline_wave = NA))
  expect_equal(get_baseline_wave(config), "W1")
})

test_that("get_baseline_wave handles empty string setting", {
  config <- create_test_config(settings = list(baseline_wave = ""))
  expect_equal(get_baseline_wave(config), "W1")
})

test_that("get_baseline_wave auto-corrects numeric to W-prefixed ID", {
  config <- create_test_config(settings = list(baseline_wave = "2"))
  # W2 is in the waves, so should auto-correct
  output <- capture.output(
    result <- get_baseline_wave(config),
    type = "output"
  )
  expect_equal(result, "W2")
})


# ==============================================================================
# TESTS: Config missing Banner columns
# ==============================================================================

test_that("load_tracking_config refuses when Banner missing required columns", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  config_path <- file.path(tmp_dir, "test_bad_banner.xlsx")

  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1", "W2"),
    WaveName = c("Wave 1", "Wave 2"),
    DataFile = c("w1.csv", "w2.csv"),
    FieldworkStart = c("2024-01-01", "2024-04-01"),
    FieldworkEnd = c("2024-01-31", "2024-04-30"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = "project_name", Value = "Test", stringsAsFactors = FALSE
  ))

  # Banner missing BreakLabel column
  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = c("Total"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("Q1"), stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  expect_error(
    load_tracking_config(config_path),
    class = "turas_refusal"
  )

  file.remove(config_path)
})


# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
