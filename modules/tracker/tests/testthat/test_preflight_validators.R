# ==============================================================================
# TESTS: Preflight Validators (preflight_validators.R)
# ==============================================================================
# Tests for the 15 cross-referential checks that validate config, waves,
# mapping, and data before the tracking analysis pipeline begins.
#
# Run with:
#   testthat::test_file("modules/tracker/tests/testthat/test_preflight_validators.R")
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Fallback root detection
if (!dir.exists(file.path(turas_root, "modules", "shared"))) {
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "shared"))) {
      turas_root <- path
      tracker_root <- file.path(path, "modules", "tracker")
      break
    }
    path <- dirname(path)
  }
}

# Source shared TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

logging_path <- file.path(turas_root, "modules", "shared", "lib", "logging_utils.R")
if (file.exists(logging_path)) source(logging_path)

# Source preflight validators
preflight_path <- file.path(tracker_root, "lib", "validation", "preflight_validators.R")
if (file.exists(preflight_path)) {
  source(preflight_path)
} else {
  stop("Cannot find preflight_validators.R at: ", preflight_path)
}


# ==============================================================================
# HELPERS
# ==============================================================================

new_error_log <- function() {
  data.frame(
    Timestamp = character(), Component = character(),
    Issue_Type = character(), Description = character(),
    QuestionCode = character(), Severity = character(),
    stringsAsFactors = FALSE
  )
}

make_waves_df <- function(ids = c("W1", "W2"),
                           starts = c("2025-01-01", "2025-07-01"),
                           ends = c("2025-01-31", "2025-07-31")) {
  data.frame(
    WaveID = ids,
    WaveLabel = paste("Wave", seq_along(ids)),
    FieldworkStart = starts,
    FieldworkEnd = ends,
    DataFile = paste0("wave_", ids, ".csv"),
    stringsAsFactors = FALSE
  )
}

make_tracked_df <- function(codes = c("Q1", "Q2"),
                             types = c("Rating", "Single"),
                             specs = c("mean", "all")) {
  data.frame(
    QuestionCode = codes,
    QuestionType = types,
    TrackingSpecs = specs,
    stringsAsFactors = FALSE
  )
}

make_mapping_df <- function(codes = c("Q1", "Q2"),
                             w1_cols = c("q1_w1", "q2_w1"),
                             w2_cols = c("q1_w2", "q2_w2")) {
  data.frame(
    QuestionCode = codes,
    W1 = w1_cols,
    W2 = w2_cols,
    stringsAsFactors = FALSE
  )
}

make_wave_data <- function(n = 50) {
  data.frame(
    q1_w1 = rnorm(n, 5, 2),
    q2_w1 = sample(1:5, n, replace = TRUE),
    Gender = sample(c("M", "F"), n, replace = TRUE),
    Weight = runif(n, 0.5, 2.0),
    stringsAsFactors = FALSE
  )
}

make_wave_data_list <- function(n = 50) {
  w1 <- make_wave_data(n)
  w2 <- w1
  names(w2) <- gsub("_w1", "_w2", names(w2))
  list(W1 = w1, W2 = w2)
}


# ==============================================================================
# TESTS
# ==============================================================================

# --- 1. check_wave_ids_unique ---

test_that("check_wave_ids_unique detects duplicate WaveIDs", {
  skip_if(!exists("check_wave_ids_unique", mode = "function"),
          "check_wave_ids_unique not available")

  waves_df <- make_waves_df(ids = c("W1", "W1", "W2"))

  result <- check_wave_ids_unique(waves_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("W1", errors$Description)))
})

test_that("check_wave_ids_unique passes with unique IDs", {
  skip_if(!exists("check_wave_ids_unique", mode = "function"),
          "check_wave_ids_unique not available")

  waves_df <- make_waves_df()
  result <- check_wave_ids_unique(waves_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 2. check_wave_dates_valid ---

test_that("check_wave_dates_valid detects start after end", {
  skip_if(!exists("check_wave_dates_valid", mode = "function"),
          "check_wave_dates_valid not available")

  waves_df <- make_waves_df(
    starts = c("2025-02-01", "2025-07-01"),
    ends = c("2025-01-01", "2025-07-31")
  )

  result <- check_wave_dates_valid(waves_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("after", errors$Description, ignore.case = TRUE)))
})

test_that("check_wave_dates_valid warns about non-chronological order", {
  skip_if(!exists("check_wave_dates_valid", mode = "function"),
          "check_wave_dates_valid not available")

  waves_df <- make_waves_df(
    starts = c("2025-07-01", "2025-01-01"),
    ends = c("2025-07-31", "2025-01-31")
  )

  result <- check_wave_dates_valid(waves_df, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


# --- 3. check_tracked_questions_in_mapping ---

test_that("check_tracked_questions_in_mapping detects unmapped questions", {
  skip_if(!exists("check_tracked_questions_in_mapping", mode = "function"),
          "check_tracked_questions_in_mapping not available")

  tracked_df <- make_tracked_df(codes = c("Q1", "Q2", "Q99"))
  mapping_df <- make_mapping_df(codes = c("Q1", "Q2"))

  result <- check_tracked_questions_in_mapping(tracked_df, mapping_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Q99", errors$Description)))
})


# --- 4. check_tracking_specs_valid ---

test_that("check_tracking_specs_valid detects invalid tokens", {
  skip_if(!exists("check_tracking_specs_valid", mode = "function"),
          "check_tracking_specs_valid not available")

  tracked_df <- data.frame(
    QuestionCode = "Q1",
    QuestionType = "Rating",
    TrackingSpecs = "mean,bogus_spec,top_box",
    stringsAsFactors = FALSE
  )

  result <- check_tracking_specs_valid(tracked_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("bogus_spec", errors$Description)))
})

test_that("check_tracking_specs_valid passes with valid specs", {
  skip_if(!exists("check_tracking_specs_valid", mode = "function"),
          "check_tracking_specs_valid not available")

  tracked_df <- data.frame(
    QuestionCode = c("Q1", "Q2"),
    QuestionType = c("Rating", "NPS"),
    TrackingSpecs = c("mean,top2_box", "nps_score,promoters_pct"),
    stringsAsFactors = FALSE
  )

  result <- check_tracking_specs_valid(tracked_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 5. check_minimum_wave_count ---

test_that("check_minimum_wave_count detects single wave", {
  skip_if(!exists("check_minimum_wave_count", mode = "function"),
          "check_minimum_wave_count not available")

  waves_df <- data.frame(WaveID = "W1", stringsAsFactors = FALSE)

  result <- check_minimum_wave_count(waves_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("at least 2", errors$Description, ignore.case = TRUE)))
})

test_that("check_minimum_wave_count passes with two waves", {
  skip_if(!exists("check_minimum_wave_count", mode = "function"),
          "check_minimum_wave_count not available")

  waves_df <- make_waves_df()
  result <- check_minimum_wave_count(waves_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 6. check_baseline_wave_valid ---

test_that("check_baseline_wave_valid detects invalid baseline wave", {
  skip_if(!exists("check_baseline_wave_valid", mode = "function"),
          "check_baseline_wave_valid not available")

  config <- list(baseline_wave = "W99")
  waves_df <- make_waves_df()

  result <- check_baseline_wave_valid(config, waves_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("W99", errors$Description)))
})

test_that("check_baseline_wave_valid skips when no baseline specified", {
  skip_if(!exists("check_baseline_wave_valid", mode = "function"),
          "check_baseline_wave_valid not available")

  config <- list(baseline_wave = NULL)
  waves_df <- make_waves_df()

  result <- check_baseline_wave_valid(config, waves_df, new_error_log())
  expect_equal(nrow(result), 0)
})


# --- 7. check_wave_files_exist ---

test_that("check_wave_files_exist detects missing files", {
  skip_if(!exists("check_wave_files_exist", mode = "function"),
          "check_wave_files_exist not available")

  waves_df <- data.frame(
    WaveID = c("W1", "W2"),
    DataFile = c("nonexistent_file1.csv", "nonexistent_file2.csv"),
    stringsAsFactors = FALSE
  )

  result <- check_wave_files_exist(waves_df, tempdir(), new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) >= 2)
})

test_that("check_wave_files_exist passes with existing files", {
  skip_if(!exists("check_wave_files_exist", mode = "function"),
          "check_wave_files_exist not available")

  tmp <- tempdir()
  f1 <- file.path(tmp, "wave1.csv")
  f2 <- file.path(tmp, "wave2.csv")
  writeLines("a,b\n1,2", f1)
  writeLines("a,b\n3,4", f2)

  waves_df <- data.frame(
    WaveID = c("W1", "W2"),
    DataFile = c("wave1.csv", "wave2.csv"),
    stringsAsFactors = FALSE
  )

  result <- check_wave_files_exist(waves_df, tmp, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)

  unlink(c(f1, f2))
})


# --- 8. check_logo_and_colours ---

test_that("check_logo_and_colours detects invalid hex colour", {
  skip_if(!exists("check_logo_and_colours", mode = "function"),
          "check_logo_and_colours not available")

  config <- list(brand_colour = "not-hex", accent_colour = "#323367")

  result <- check_logo_and_colours(config, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})

test_that("check_logo_and_colours passes with valid hex colours", {
  skip_if(!exists("check_logo_and_colours", mode = "function"),
          "check_logo_and_colours not available")

  config <- list(brand_colour = "#1e3a5f", accent_colour = "#2aa198")

  result <- check_logo_and_colours(config, new_error_log())
  expect_equal(nrow(result), 0)
})


# --- 9. check_nps_question_range ---

test_that("check_nps_question_range detects out-of-range NPS data", {
  skip_if(!exists("check_nps_question_range", mode = "function"),
          "check_nps_question_range not available")

  tracked_df <- data.frame(
    QuestionCode = "QNPS", QuestionType = "NPS",
    TrackingSpecs = "nps_score", stringsAsFactors = FALSE
  )
  mapping_df <- data.frame(
    QuestionCode = "QNPS", W1 = "nps_col",
    stringsAsFactors = FALSE
  )
  wave_data_list <- list(
    W1 = data.frame(nps_col = c(0, 5, 10, 15, -1), stringsAsFactors = FALSE)
  )

  result <- check_nps_question_range(tracked_df, mapping_df, wave_data_list, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("0-10", errors$Description)))
})


# --- 10. check_rating_question_numeric ---

test_that("check_rating_question_numeric detects non-numeric data", {
  skip_if(!exists("check_rating_question_numeric", mode = "function"),
          "check_rating_question_numeric not available")

  tracked_df <- data.frame(
    QuestionCode = "QR", QuestionType = "Rating",
    TrackingSpecs = "mean", stringsAsFactors = FALSE
  )
  mapping_df <- data.frame(
    QuestionCode = "QR", W1 = "rating_col",
    stringsAsFactors = FALSE
  )
  wave_data_list <- list(
    W1 = data.frame(
      rating_col = c("good", "bad", "ok", "5", "3", "good", "bad", "ok", "1", "2"),
      stringsAsFactors = FALSE
    )
  )

  result <- check_rating_question_numeric(tracked_df, mapping_df, wave_data_list, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


# --- 11. validate_tracker_preflight orchestrator ---

test_that("validate_tracker_preflight runs on minimal valid inputs", {
  skip_if(!exists("validate_tracker_preflight", mode = "function"),
          "validate_tracker_preflight not available")

  tmp <- tempdir()
  f1 <- file.path(tmp, "w1_data.csv")
  f2 <- file.path(tmp, "w2_data.csv")
  writeLines("q1,q2,Gender\n1,2,M\n3,4,F", f1)
  writeLines("q1,q2,Gender\n1,2,M\n3,4,F", f2)

  waves_df <- data.frame(
    WaveID = c("W1", "W2"),
    DataFile = c("w1_data.csv", "w2_data.csv"),
    FieldworkStart = c("2025-01-01", "2025-07-01"),
    FieldworkEnd = c("2025-01-31", "2025-07-31"),
    stringsAsFactors = FALSE
  )
  tracked_df <- data.frame(
    QuestionCode = "Q1", QuestionType = "Single",
    TrackingSpecs = "all", stringsAsFactors = FALSE
  )
  mapping_df <- data.frame(
    QuestionCode = "Q1", W1 = "q1", W2 = "q1",
    stringsAsFactors = FALSE
  )
  w1_data <- data.frame(q1 = c(1, 2), q2 = c(3, 4), Gender = c("M", "F"),
                         stringsAsFactors = FALSE)
  w2_data <- w1_data
  wave_data_list <- list(W1 = w1_data, W2 = w2_data)
  config <- list(baseline_wave = "W1")

  result <- validate_tracker_preflight(
    config, waves_df, tracked_df, mapping_df, wave_data_list,
    config_dir = tmp, verbose = FALSE
  )
  expect_true(is.data.frame(result))

  unlink(c(f1, f2))
})

test_that("validate_tracker_preflight detects issues in bad config", {
  skip_if(!exists("validate_tracker_preflight", mode = "function"),
          "validate_tracker_preflight not available")

  waves_df <- data.frame(
    WaveID = c("W1"),
    DataFile = "missing.csv",
    stringsAsFactors = FALSE
  )
  tracked_df <- data.frame(
    QuestionCode = "Q99", QuestionType = "Rating",
    TrackingSpecs = "bogus_spec", stringsAsFactors = FALSE
  )
  mapping_df <- data.frame(
    QuestionCode = "Q1", W1 = "q1",
    stringsAsFactors = FALSE
  )
  config <- list(baseline_wave = "W_BAD")

  result <- validate_tracker_preflight(
    config, waves_df, tracked_df, mapping_df,
    wave_data_list = list(), config_dir = tempdir(), verbose = FALSE
  )
  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)
})
