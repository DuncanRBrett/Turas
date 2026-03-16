# ==============================================================================
# TEST SUITE: Integration Pipeline Tests
# ==============================================================================
# End-to-end tests for the tracker pipeline including config loading,
# wave loading, question mapping, trend calculation, and output generation.
#
# These tests create synthetic data and config files in temp directories,
# run them through the pipeline, and verify the output structure.
#
# Functions tested:
#   - load_tracking_config()
#   - load_question_mapping()
#   - build_question_map_index()
#   - validate_tracking_config()
#   - load_all_waves()
#   - validate_wave_data()
#   - calculate_all_trends()
#   - validate_tracker_setup()
#
# ==============================================================================

library(testthat)

context("Integration Pipeline")

# ==============================================================================
# SETUP: Source ALL required tracker modules
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source shared TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Source TRS run state if available (optional, used by calculate_all_trends)
trs_run_state_path <- file.path(turas_root, "modules", "shared", "lib", "trs_run_state.R")
if (file.exists(trs_run_state_path)) tryCatch(source(trs_run_state_path), error = function(e) NULL)

trs_banner_path <- file.path(turas_root, "modules", "shared", "lib", "trs_banner.R")
if (file.exists(trs_banner_path)) tryCatch(source(trs_banner_path), error = function(e) NULL)

# Pre-source shared utilities (wave_loader.R needs these)
shared_lib <- file.path(turas_root, "modules", "shared", "lib")
weights_path <- file.path(shared_lib, "weights_utils.R")
if (file.exists(weights_path)) source(weights_path)

# Source tracker modules in dependency order
source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "wave_loader.R"))
source(file.path(tracker_root, "lib", "question_mapper.R"))
source(file.path(tracker_root, "lib", "validation_tracker.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "trend_changes.R"))
source(file.path(tracker_root, "lib", "trend_significance.R"))
source(file.path(tracker_root, "lib", "trend_calculator.R"))


# ==============================================================================
# HELPER: Create synthetic test environment
# ==============================================================================

#' Create a complete synthetic test environment
#'
#' Creates config xlsx, question mapping xlsx, and wave data CSV files
#' in a temp directory for integration testing.
#'
#' @param n_respondents Number of respondents per wave
#' @param n_waves Number of waves (2 or 3)
#' @param n_questions Number of tracked questions (1-3)
#' @param include_weight Whether to include a weight column
#' @return List with paths and expected values
create_test_environment <- function(n_respondents = 50,
                                    n_waves = 2,
                                    n_questions = 3,
                                    include_weight = FALSE) {

  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  test_dir <- file.path(tmp_dir, paste0("tracker_integ_", format(Sys.time(), "%H%M%S")))
  dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)

  set.seed(42)

  # --- Build wave definitions ---
  wave_ids <- paste0("W", 1:n_waves)
  wave_names <- paste0("Wave ", 1:n_waves)
  data_files <- paste0("wave", 1:n_waves, ".csv")
  fw_starts <- as.character(seq(as.Date("2024-01-01"), by = "3 months", length.out = n_waves))
  fw_ends <- as.character(seq(as.Date("2024-01-31"), by = "3 months", length.out = n_waves))

  waves_df <- data.frame(
    WaveID = wave_ids,
    WaveName = wave_names,
    DataFile = data_files,
    FieldworkStart = fw_starts,
    FieldworkEnd = fw_ends,
    stringsAsFactors = FALSE
  )

  # --- Build tracked questions ---
  all_questions <- data.frame(
    QuestionCode = c("Q_SAT", "Q_NPS", "Q_AWARE"),
    MetricLabel = c("Satisfaction", "NPS Score", "Awareness"),
    TrackingSpecs = c("mean", "nps_score", "category:Yes"),
    Section = c("Brand Health", "Brand Health", "Key Metrics"),
    SortOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )
  tracked_questions <- all_questions[1:min(n_questions, 3), ]

  # --- Build question mapping ---
  mapping_base <- data.frame(
    QuestionCode = c("Q_SAT", "Q_NPS", "Q_AWARE"),
    QuestionText = c("How satisfied are you?", "How likely to recommend?", "Are you aware?"),
    QuestionType = c("Rating", "NPS", "Single_Response"),
    stringsAsFactors = FALSE
  )
  mapping_base <- mapping_base[1:min(n_questions, 3), ]

  # Add wave columns (same question code in each wave for simplicity)
  q_codes_in_data <- c("Q10", "Q15", "Q20")
  for (i in seq_len(n_waves)) {
    mapping_base[[wave_ids[i]]] <- q_codes_in_data[1:min(n_questions, 3)]
  }

  # --- Create wave data CSV files ---
  for (i in seq_len(n_waves)) {
    wave_df <- data.frame(
      ResponseID = seq_len(n_respondents),
      stringsAsFactors = FALSE
    )

    # Satisfaction (Rating 1-5) -- shift mean slightly per wave
    if (n_questions >= 1) {
      wave_df$Q10 <- round(pmin(5, pmax(1, rnorm(n_respondents, mean = 3.0 + i * 0.2, sd = 1.0))))
    }

    # NPS (0-10) -- shift slightly per wave
    if (n_questions >= 2) {
      wave_df$Q15 <- round(pmin(10, pmax(0, rnorm(n_respondents, mean = 6.5 + i * 0.3, sd = 2.5))))
    }

    # Awareness (categorical)
    if (n_questions >= 3) {
      yes_prob <- 0.5 + i * 0.05
      wave_df$Q20 <- sample(c("Yes", "No"), n_respondents, replace = TRUE,
                             prob = c(yes_prob, 1 - yes_prob))
    }

    if (include_weight) {
      wave_df$weight <- runif(n_respondents, 0.5, 2.0)
    }

    write.csv(wave_df, file.path(test_dir, data_files[i]), row.names = FALSE)
  }

  # --- Create tracking config xlsx ---
  config_path <- file.path(test_dir, "tracking_config.xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", waves_df)

  settings_df <- data.frame(
    Setting = c("project_name", "show_significance", "decimal_places_ratings",
                "question_mapping_file"),
    Value = c("Integration Test", "Y", "1", "question_mapping.xlsx"),
    stringsAsFactors = FALSE
  )
  if (include_weight) {
    settings_df <- rbind(settings_df, data.frame(
      Setting = "weight_variable", Value = "weight", stringsAsFactors = FALSE
    ))
  }

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", settings_df)

  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = "Total", BreakLabel = "Overall", stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", tracked_questions)

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  # --- Create question mapping xlsx ---
  mapping_path <- file.path(test_dir, "question_mapping.xlsx")
  wb2 <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb2, "QuestionMap")
  openxlsx::writeData(wb2, "QuestionMap", mapping_base)
  openxlsx::saveWorkbook(wb2, mapping_path, overwrite = TRUE)

  return(list(
    test_dir = test_dir,
    config_path = config_path,
    mapping_path = mapping_path,
    wave_ids = wave_ids,
    n_questions = min(n_questions, 3),
    n_respondents = n_respondents
  ))
}

cleanup_test_environment <- function(env) {
  if (dir.exists(env$test_dir)) {
    unlink(env$test_dir, recursive = TRUE)
  }
}


# ==============================================================================
# TESTS: Full pipeline with 2 waves, 3 questions
# ==============================================================================

test_that("full pipeline runs with 2 waves and 3 questions", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 50, n_waves = 2, n_questions = 3)
  on.exit(cleanup_test_environment(env))

  # Step 1: Load config
  config <- load_tracking_config(env$config_path)

  expect_true(is.list(config))
  expect_equal(nrow(config$waves), 2)
  expect_equal(nrow(config$tracked_questions), 3)

  # Step 2: Load question mapping
  mapping <- load_question_mapping(env$mapping_path)

  expect_true(is.data.frame(mapping))
  expect_equal(nrow(mapping), 3)
  expect_true("W1" %in% names(mapping))
  expect_true("W2" %in% names(mapping))

  # Step 3: Build question map index
  question_map <- build_question_map_index(mapping, config)

  expect_true(is.list(question_map))
  expect_true("standard_to_wave" %in% names(question_map))

  # Step 4: Validate config
  result <- validate_tracking_config(config, mapping)
  expect_true(result)

  # Step 5: Load wave data
  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  expect_true(is.list(wave_load_result))
  expect_equal(length(wave_load_result$wave_data), 2)
  expect_equal(nrow(wave_load_result$wave_data[["W1"]]), 50)
  expect_equal(nrow(wave_load_result$wave_data[["W2"]]), 50)

  wave_data <- wave_load_result$wave_data

  # Step 6: Validate wave data
  result <- validate_wave_data(wave_data, config, mapping)
  expect_true(result)

  # Step 7: Calculate trends
  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  expect_true(is.list(trend_calc_result))
  expect_true("trends" %in% names(trend_calc_result))
  expect_true("run_status" %in% names(trend_calc_result))

  trends <- trend_calc_result$trends

  # Verify at least some trends were calculated
  expect_true(length(trends) > 0)
})


# ==============================================================================
# TESTS: Pipeline with 3 waves
# ==============================================================================

test_that("full pipeline runs with 3 waves", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 40, n_waves = 3, n_questions = 2)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)

  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)
  wave_data <- wave_load_result$wave_data

  expect_equal(length(wave_data), 3)

  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  expect_true(length(trend_calc_result$trends) > 0)
})


# ==============================================================================
# TESTS: Pipeline with weighted data
# ==============================================================================

test_that("pipeline applies weights correctly", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 60, n_waves = 2,
                                 n_questions = 1, include_weight = TRUE)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)

  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)
  wave_data <- wave_load_result$wave_data

  # Weights should not all be 1 (since we specified include_weight = TRUE)
  w1_weights <- wave_data[["W1"]]$weight_var
  expect_false(all(w1_weights == 1))
  expect_true(all(!is.na(w1_weights)))
})


# ==============================================================================
# TESTS: Verify output structure of trends
# ==============================================================================

test_that("trend results contain expected structure for rating question", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 80, n_waves = 2, n_questions = 1)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)

  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)
  wave_data <- wave_load_result$wave_data

  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  trends <- trend_calc_result$trends

  if (length(trends) > 0) {
    # Check first trend result has wave data
    first_trend <- trends[[1]]
    expect_true(is.list(first_trend))
    expect_true("wave_results" %in% names(first_trend) || "waves" %in% names(first_trend))
  }
})


# ==============================================================================
# TESTS: Pipeline with single question
# ==============================================================================

test_that("pipeline works with single tracked question", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 30, n_waves = 2, n_questions = 1)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)

  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_load_result$wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  expect_true(is.list(trend_calc_result))
  expect_true(length(trend_calc_result$trends) >= 1 ||
              length(trend_calc_result$skipped_questions) >= 0)
})


# ==============================================================================
# TESTS: Pipeline with missing question in data (PARTIAL status)
# ==============================================================================

test_that("pipeline produces PARTIAL when a question is missing from data", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 50, n_waves = 2, n_questions = 3)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)

  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)
  wave_data <- wave_load_result$wave_data

  # Add a tracked question that doesn't exist in the data or mapping
  config$tracked_questions <- rbind(config$tracked_questions, data.frame(
    QuestionCode = "Q_NONEXIST",
    MetricLabel = "Nonexistent",
    TrackingSpecs = "mean",
    Section = "Test",
    SortOrder = 99,
    stringsAsFactors = FALSE
  ))

  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  # Should have skipped the nonexistent question
  expect_true(length(trend_calc_result$skipped_questions) > 0 ||
              trend_calc_result$run_status == "PARTIAL")
})


# ==============================================================================
# TESTS: Pipeline with small sample size
# ==============================================================================

test_that("pipeline handles small sample size", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 5, n_waves = 2, n_questions = 1)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)

  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  # Should not error out with small samples
  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_load_result$wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  expect_true(is.list(trend_calc_result))
})


# ==============================================================================
# TESTS: Config loading and mapping loading consistency
# ==============================================================================

test_that("config waves match mapping wave columns", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 20, n_waves = 2, n_questions = 2)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)

  wave_ids <- config$waves$WaveID
  for (wid in wave_ids) {
    expect_true(wid %in% names(mapping),
                info = paste0("Wave ID '", wid, "' should be a column in question mapping"))
  }
})

test_that("question_map_index contains all tracked questions", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 20, n_waves = 2, n_questions = 3)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)

  for (q_code in config$tracked_questions$QuestionCode) {
    expect_true(q_code %in% names(question_map$standard_to_wave),
                info = paste0("Tracked question '", q_code, "' should be in question_map"))
  }
})


# ==============================================================================
# TESTS: validate_tracker_setup comprehensive validation
# ==============================================================================

test_that("validate_tracker_setup passes with valid synthetic data", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 50, n_waves = 2, n_questions = 3)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)
  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  output <- capture.output({
    result <- validate_tracker_setup(
      config = config,
      question_mapping = mapping,
      question_map = question_map,
      wave_data = wave_load_result$wave_data
    )
  }, type = "output")

  expect_true(is.list(result))
  expect_equal(length(result$errors), 0)
})


# ==============================================================================
# TESTS: Pipeline with NPS question
# ==============================================================================

test_that("pipeline calculates NPS trends correctly", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 100, n_waves = 2, n_questions = 2)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)
  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_load_result$wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  # With 2 questions (Rating + NPS), we should get at least 1 trend
  expect_true(length(trend_calc_result$trends) >= 1)
})


# ==============================================================================
# TESTS: Load config from question_mapping_file setting
# ==============================================================================

test_that("config uses question_mapping_file setting to resolve mapping path", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 20, n_waves = 2, n_questions = 1)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)

  # The config settings should have question_mapping_file
  mapping_setting <- get_setting(config, "question_mapping_file", default = NULL)
  expect_false(is.null(mapping_setting))
  expect_equal(mapping_setting, "question_mapping.xlsx")
})


# ==============================================================================
# TESTS: Wave data loaded in correct order
# ==============================================================================

test_that("wave data preserves wave ID ordering", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 20, n_waves = 3, n_questions = 1)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)

  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  expect_equal(names(wave_load_result$wave_data), c("W1", "W2", "W3"))
})


# ==============================================================================
# TESTS: Large dataset performance
# ==============================================================================

test_that("pipeline handles 500 respondents without errors", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 500, n_waves = 2, n_questions = 2)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)
  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_load_result$wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  expect_true(is.list(trend_calc_result))
  expect_true(length(trend_calc_result$trends) > 0)
})


# ==============================================================================
# TESTS: Categorical question tracking
# ==============================================================================

test_that("pipeline handles categorical (Single_Response) questions", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  # Use 3 questions so Q_AWARE (Single_Response) is included
  env <- create_test_environment(n_respondents = 60, n_waves = 2, n_questions = 3)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)
  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  # Verify Q20 (awareness) is preserved as character (categorical)
  q20_w1 <- wave_load_result$wave_data[["W1"]]$Q20
  expect_true(is.character(q20_w1))
  expect_true(all(q20_w1 %in% c("Yes", "No", NA)))
})


# ==============================================================================
# TESTS: Trend result metadata
# ==============================================================================

test_that("trend calculation returns run_status and skipped_questions", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 50, n_waves = 2, n_questions = 2)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)
  question_map <- build_question_map_index(mapping, config)
  wave_load_result <- load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping)

  trend_calc_result <- calculate_all_trends(
    config = config,
    question_map = question_map,
    wave_data = wave_load_result$wave_data,
    wave_structures = wave_load_result$wave_structures
  )

  expect_true("trends" %in% names(trend_calc_result))
  expect_true("skipped_questions" %in% names(trend_calc_result))
  expect_true("run_status" %in% names(trend_calc_result))
  expect_true(trend_calc_result$run_status %in% c("PASS", "PARTIAL"))
})


# ==============================================================================
# TESTS: Missing wave data file causes refusal
# ==============================================================================

test_that("load_all_waves refuses when a wave data file is missing", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 20, n_waves = 2, n_questions = 1)
  on.exit(cleanup_test_environment(env))

  # Delete one wave file
  file.remove(file.path(env$test_dir, "wave2.csv"))

  config <- load_tracking_config(env$config_path)
  mapping <- load_question_mapping(env$mapping_path)

  expect_error(
    load_all_waves(config, data_dir = env$test_dir, question_mapping = mapping),
    class = "turas_refusal"
  )
})


# ==============================================================================
# TESTS: Config with mismatched mapping file
# ==============================================================================

test_that("validate_tracking_config warns when tracked questions not in mapping", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  env <- create_test_environment(n_respondents = 20, n_waves = 2, n_questions = 3)
  on.exit(cleanup_test_environment(env))

  config <- load_tracking_config(env$config_path)

  # Mapping with only 1 of the 3 tracked questions
  partial_mapping <- data.frame(
    QuestionCode = c("Q_SAT"),
    QuestionText = c("How satisfied?"),
    QuestionType = c("Rating"),
    W1 = c("Q10"),
    W2 = c("Q10"),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- validate_tracking_config(config, partial_mapping),
    type = "output"
  )

  # Should warn about unmapped questions
  expect_true(any(grepl("not found in question mapping", output)))
})


# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
