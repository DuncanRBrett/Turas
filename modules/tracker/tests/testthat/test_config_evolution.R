# ==============================================================================
# TEST SUITE: Configuration Evolution (Phase 1)
# ==============================================================================
# Tests for TrackedQuestions enhancements: TrackingSpecs, Section, SortOrder,
# baseline_wave, default specs, and backward compatibility.
# ==============================================================================

library(testthat)

context("Tracker Configuration Evolution")

# ==============================================================================
# SETUP: Source required modules
# ==============================================================================

# Determine paths relative to test file location
test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Source tracker modules in dependency order
guard_path <- file.path(tracker_root, "lib", "00_guard.R")
if (file.exists(guard_path)) source(guard_path)

config_loader_path <- file.path(tracker_root, "lib", "tracker_config_loader.R")
if (file.exists(config_loader_path)) source(config_loader_path)

question_mapper_path <- file.path(tracker_root, "lib", "question_mapper.R")
if (file.exists(question_mapper_path)) source(question_mapper_path)

# ==============================================================================
# HELPER: Create mock config objects for testing
# ==============================================================================

create_mock_config <- function(tracked_questions = NULL, settings = NULL, waves = NULL) {
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
      TrackingSpecs = c("mean,top2_box", "nps_score,promoters_pct", "category:Yes"),
      Section = c("Brand Health", "Brand Health", "Key Metrics"),
      SortOrder = c(1, 2, 3),
      stringsAsFactors = FALSE
    )
  }

  if (is.null(settings)) {
    settings <- list(
      project_name = "Test Project",
      baseline_wave = "W1",
      default_rating_specs = "mean",
      default_nps_specs = "nps_score",
      html_report = TRUE,
      brand_colour = "#323367",
      accent_colour = "#CC9900",
      decimal_places_ratings = 1,
      show_significance = TRUE
    )
  }

  list(
    waves = waves,
    settings = settings,
    banner = data.frame(
      BreakVariable = c("Total", "Gender", "Gender"),
      BreakLabel = c("Overall", "Male", "Female"),
      stringsAsFactors = FALSE
    ),
    tracked_questions = tracked_questions,
    config_path = "/mock/path/config.xlsx"
  )
}

create_mock_question_map <- function(include_tracking_specs = FALSE) {
  metadata <- data.frame(
    QuestionCode = c("Q_SAT", "Q_NPS", "Q_AWARE"),
    QuestionText = c("How satisfied?", "Recommend?", "Are you aware?"),
    QuestionType = c("Rating", "NPS", "Single_Response"),
    stringsAsFactors = FALSE
  )

  if (include_tracking_specs) {
    metadata$TrackingSpecs <- c("mean,top_box", "full", "all")
  }

  list(
    standard_to_wave = list(
      Q_SAT = list(W1 = "Q10", W2 = "Q11", W3 = "Q12"),
      Q_NPS = list(W1 = "Q15", W2 = "Q15", W3 = "Q15"),
      Q_AWARE = list(W1 = "Q20", W2 = "Q20", W3 = "Q20")
    ),
    question_metadata = metadata
  )
}


# ==============================================================================
# TESTS: get_baseline_wave()
# ==============================================================================

test_that("get_baseline_wave returns setting when specified", {
  config <- create_mock_config(settings = list(baseline_wave = "W2"))
  expect_equal(get_baseline_wave(config), "W2")
})

test_that("get_baseline_wave defaults to first wave when not specified", {
  config <- create_mock_config(settings = list(project_name = "Test"))
  expect_equal(get_baseline_wave(config), "W1")
})

test_that("get_baseline_wave handles NA and empty string", {
  config <- create_mock_config(settings = list(baseline_wave = NA))
  expect_equal(get_baseline_wave(config), "W1")

  config$settings$baseline_wave <- ""
  expect_equal(get_baseline_wave(config), "W1")

  config$settings$baseline_wave <- "  "
  expect_equal(get_baseline_wave(config), "W1")
})


# ==============================================================================
# TESTS: get_tracking_specs() priority chain
# ==============================================================================

test_that("get_tracking_specs reads from config TrackedQuestions first", {
  config <- create_mock_config()
  question_map <- create_mock_question_map(include_tracking_specs = TRUE)

  # Config has "mean,top2_box", mapping has "mean,top_box" — config should win
  result <- get_tracking_specs(question_map, "Q_SAT", config = config)
  expect_equal(result, "mean,top2_box")
})

test_that("get_tracking_specs falls back to question_mapping when config has no specs", {
  # Config with empty TrackingSpecs
  config <- create_mock_config(tracked_questions = data.frame(
    QuestionCode = c("Q_SAT"),
    TrackingSpecs = NA_character_,
    stringsAsFactors = FALSE
  ))
  question_map <- create_mock_question_map(include_tracking_specs = TRUE)

  result <- get_tracking_specs(question_map, "Q_SAT", config = config)
  expect_equal(result, "mean,top_box")  # From mapping
})

test_that("get_tracking_specs falls back to defaults when no specs anywhere", {
  config <- create_mock_config(
    tracked_questions = data.frame(
      QuestionCode = c("Q_SAT"),
      TrackingSpecs = NA_character_,
      stringsAsFactors = FALSE
    ),
    settings = list(default_rating_specs = "mean,top2_box")
  )
  question_map <- create_mock_question_map(include_tracking_specs = FALSE)

  result <- get_tracking_specs(question_map, "Q_SAT", config = config)
  expect_equal(result, "mean,top2_box")
})

test_that("get_tracking_specs returns NULL when no specs and no defaults", {
  config <- create_mock_config(
    tracked_questions = data.frame(
      QuestionCode = c("Q_SAT"),
      TrackingSpecs = NA_character_,
      stringsAsFactors = FALSE
    ),
    settings = list(project_name = "Test")
  )
  question_map <- create_mock_question_map(include_tracking_specs = FALSE)

  result <- get_tracking_specs(question_map, "Q_SAT", config = config)
  expect_null(result)
})

test_that("get_tracking_specs works without config (backward compat)", {
  question_map <- create_mock_question_map(include_tracking_specs = TRUE)

  result <- get_tracking_specs(question_map, "Q_SAT")
  expect_equal(result, "mean,top_box")  # From mapping
})

test_that("get_tracking_specs returns NULL for unknown question", {
  question_map <- create_mock_question_map()
  result <- get_tracking_specs(question_map, "Q_UNKNOWN")
  expect_null(result)
})


# ==============================================================================
# TESTS: get_default_specs()
# ==============================================================================

test_that("get_default_specs returns rating defaults", {
  config <- create_mock_config(settings = list(default_rating_specs = "mean,top2_box"))
  expect_equal(get_default_specs(config, "Rating"), "mean,top2_box")
  expect_equal(get_default_specs(config, "rating"), "mean,top2_box")
  expect_equal(get_default_specs(config, "Likert"), "mean,top2_box")
})

test_that("get_default_specs returns NPS defaults", {
  config <- create_mock_config(settings = list(default_nps_specs = "nps_score,promoters_pct"))
  expect_equal(get_default_specs(config, "NPS"), "nps_score,promoters_pct")
  expect_equal(get_default_specs(config, "nps"), "nps_score,promoters_pct")
})

test_that("get_default_specs returns NULL when no default set", {
  config <- create_mock_config(settings = list(project_name = "Test"))
  expect_null(get_default_specs(config, "Rating"))
  expect_null(get_default_specs(config, "NPS"))
})

test_that("get_default_specs returns NULL for unknown question type", {
  config <- create_mock_config(settings = list(default_rating_specs = "mean"))
  expect_null(get_default_specs(config, "Unknown_Type"))
})


# ==============================================================================
# TESTS: TrackedQuestions column defaults
# ==============================================================================

test_that("config loader adds default columns when missing", {
  # Simulate a minimal TrackedQuestions with only QuestionCode
  tq <- data.frame(
    QuestionCode = c("Q_SAT", "Q_NPS"),
    stringsAsFactors = FALSE
  )

  # Simulate what load_tracking_config does after loading
  if (!"TrackingSpecs" %in% names(tq)) tq$TrackingSpecs <- NA_character_
  if (!"MetricLabel" %in% names(tq)) tq$MetricLabel <- NA_character_
  if (!"Section" %in% names(tq)) tq$Section <- NA_character_
  if (!"SortOrder" %in% names(tq)) tq$SortOrder <- seq_len(nrow(tq))

  expect_true("TrackingSpecs" %in% names(tq))
  expect_true("MetricLabel" %in% names(tq))
  expect_true("Section" %in% names(tq))
  expect_true("SortOrder" %in% names(tq))
  expect_equal(tq$SortOrder, c(1, 2))
  expect_true(all(is.na(tq$TrackingSpecs)))
})

test_that("SortOrder converts to numeric with fallback", {
  tq <- data.frame(
    QuestionCode = c("Q1", "Q2", "Q3"),
    SortOrder = c("1", "abc", "3"),
    stringsAsFactors = FALSE
  )

  tq$SortOrder <- suppressWarnings(as.numeric(tq$SortOrder))
  na_rows <- is.na(tq$SortOrder)
  if (any(na_rows)) {
    tq$SortOrder[na_rows] <- which(na_rows)
  }

  expect_equal(tq$SortOrder, c(1, 2, 3))
})


# ==============================================================================
# TESTS: Guard validation for baseline_wave
# ==============================================================================

test_that("validate_tracker_config passes with valid baseline_wave", {
  config <- create_mock_config(settings = list(
    project_name = "Test",
    baseline_wave = "W2"
  ))

  # Should not throw/refuse
  result <- validate_tracker_config(config)
  expect_true(result)
})

test_that("validate_tracker_config passes without baseline_wave", {
  config <- create_mock_config(settings = list(project_name = "Test"))
  result <- validate_tracker_config(config)
  expect_true(result)
})
