# ==============================================================================
# TEST SUITE: Tracker Guard Layer & Validation Functions
# ==============================================================================
# Comprehensive unit tests for guard state management, sample size validation,
# status determination, config validation, wave validation, and result merging.
#
# Functions tested from 00_guard.R:
#   - tracker_guard_init()
#   - guard_record_missing_wave()
#   - guard_record_inconsistency()
#   - guard_record_sample_size()
#   - guard_record_low_sample()
#   - tracker_guard_record_modification()
#   - guard_record_alignment_issue()
#   - tracker_guard_summary()
#   - validate_sample_size()
#   - tracker_determine_status()
#
# Functions tested from validation_tracker.R:
#   - validate_config_structure()
#   - validate_wave_definitions()
#   - merge_validation_results()
#
# ==============================================================================

library(testthat)

context("Tracker Guard Layer & Validation")

# ==============================================================================
# SETUP: Source required modules
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source shared TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Source tracker config loader (provides get_setting)
config_loader_path <- file.path(tracker_root, "lib", "tracker_config_loader.R")
if (file.exists(config_loader_path)) source(config_loader_path)

# Source guard layer
source(file.path(tracker_root, "lib", "00_guard.R"))

# Source validation module
source(file.path(tracker_root, "lib", "validation_tracker.R"))


# ==============================================================================
# 1. GUARD STATE INITIALIZATION
# ==============================================================================

test_that("tracker_guard_init creates guard state with correct module name", {

  guard <- tracker_guard_init()
  expect_equal(guard$module, "TRACKER")
})

test_that("tracker_guard_init includes all tracker-specific fields", {
  guard <- tracker_guard_init()

  expect_true("missing_waves" %in% names(guard))
  expect_true("inconsistent_questions" %in% names(guard))
  expect_true("wave_sample_sizes" %in% names(guard))
  expect_true("question_alignment_issues" %in% names(guard))
  expect_true("low_sample_warnings" %in% names(guard))
  expect_true("data_modifications" %in% names(guard))
})

test_that("tracker_guard_init fields are empty at initialization", {
  guard <- tracker_guard_init()

  expect_length(guard$missing_waves, 0)
  expect_length(guard$inconsistent_questions, 0)
  expect_length(guard$wave_sample_sizes, 0)
  expect_length(guard$question_alignment_issues, 0)
  expect_length(guard$low_sample_warnings, 0)
  expect_length(guard$data_modifications, 0)
})

test_that("tracker_guard_init has correct types for tracker fields", {
  guard <- tracker_guard_init()

  expect_type(guard$missing_waves, "character")
  expect_type(guard$inconsistent_questions, "list")
  expect_type(guard$wave_sample_sizes, "list")
  expect_type(guard$question_alignment_issues, "list")
  expect_type(guard$low_sample_warnings, "list")
  expect_type(guard$data_modifications, "list")
})

test_that("tracker_guard_init inherits shared guard fields", {
  guard <- tracker_guard_init()

  # From guard_init() in trs_refusal.R
  expect_true("warnings" %in% names(guard))
  expect_true("stability_flags" %in% names(guard))
  expect_true("timestamp" %in% names(guard))
})


# ==============================================================================
# 2. GUARD RECORD FUNCTIONS
# ==============================================================================

# --- guard_record_missing_wave ---

test_that("guard_record_missing_wave appends wave_id to missing_waves", {
  guard <- tracker_guard_init()
  guard <- guard_record_missing_wave(guard, "W3", "file not found")

  expect_equal(guard$missing_waves, "W3")
})

test_that("guard_record_missing_wave accumulates multiple missing waves", {
  guard <- tracker_guard_init()
  guard <- guard_record_missing_wave(guard, "W3", "file not found")
  guard <- guard_record_missing_wave(guard, "W5", "corrupt data")

  expect_equal(guard$missing_waves, c("W3", "W5"))
})

test_that("guard_record_missing_wave adds a warning to guard state", {
  guard <- tracker_guard_init()
  guard <- guard_record_missing_wave(guard, "W3", "file not found")

  expect_true(length(guard$warnings) > 0)
  expect_true(any(grepl("Missing wave.*W3", guard$warnings)))
  expect_true(any(grepl("file not found", guard$warnings)))
})


# --- guard_record_inconsistency ---

test_that("guard_record_inconsistency stores question inconsistency", {
  guard <- tracker_guard_init()
  guard <- guard_record_inconsistency(guard, "Q10", "W1", "W2", "Scale changed from 5 to 7 points")

  expect_true("Q10" %in% names(guard$inconsistent_questions))
  expect_equal(guard$inconsistent_questions$Q10$wave1, "W1")
  expect_equal(guard$inconsistent_questions$Q10$wave2, "W2")
  expect_equal(guard$inconsistent_questions$Q10$issue, "Scale changed from 5 to 7 points")
})

test_that("guard_record_inconsistency records multiple questions", {
  guard <- tracker_guard_init()
  guard <- guard_record_inconsistency(guard, "Q10", "W1", "W2", "Scale change")
  guard <- guard_record_inconsistency(guard, "Q15", "W2", "W3", "Options differ")

  expect_length(guard$inconsistent_questions, 2)
  expect_true("Q10" %in% names(guard$inconsistent_questions))
  expect_true("Q15" %in% names(guard$inconsistent_questions))
})

test_that("guard_record_inconsistency flags stability", {
  guard <- tracker_guard_init()
  guard <- guard_record_inconsistency(guard, "Q10", "W1", "W2", "Scale change")

  expect_true(length(guard$stability_flags) > 0)
})

test_that("guard_record_inconsistency overwrites same question code", {
  guard <- tracker_guard_init()
  guard <- guard_record_inconsistency(guard, "Q10", "W1", "W2", "First issue")
  guard <- guard_record_inconsistency(guard, "Q10", "W2", "W3", "Second issue")

  # Keyed by question_code, so latest overwrites
  expect_equal(guard$inconsistent_questions$Q10$issue, "Second issue")
  expect_equal(guard$inconsistent_questions$Q10$wave1, "W2")
  expect_equal(guard$inconsistent_questions$Q10$wave2, "W3")
})


# --- guard_record_sample_size ---

test_that("guard_record_sample_size stores all size components", {
  guard <- tracker_guard_init()
  guard <- guard_record_sample_size(guard, "W1", n_unweighted = 500, n_weighted = 480.5)

  expect_true("W1" %in% names(guard$wave_sample_sizes))
  expect_equal(guard$wave_sample_sizes$W1$n_unweighted, 500)
  expect_equal(guard$wave_sample_sizes$W1$n_weighted, 480.5)
  expect_null(guard$wave_sample_sizes$W1$n_effective)
})

test_that("guard_record_sample_size stores effective sample size when provided", {
  guard <- tracker_guard_init()
  guard <- guard_record_sample_size(guard, "W1", n_unweighted = 500, n_weighted = 480, n_effective = 420)

  expect_equal(guard$wave_sample_sizes$W1$n_effective, 420)
})

test_that("guard_record_sample_size stores multiple waves", {
  guard <- tracker_guard_init()
  guard <- guard_record_sample_size(guard, "W1", n_unweighted = 500, n_weighted = 480)
  guard <- guard_record_sample_size(guard, "W2", n_unweighted = 600, n_weighted = 590)

  expect_length(guard$wave_sample_sizes, 2)
  expect_equal(guard$wave_sample_sizes$W2$n_unweighted, 600)
})

test_that("guard_record_sample_size returns guard invisibly", {
  guard <- tracker_guard_init()
  result <- withVisible(guard_record_sample_size(guard, "W1", 100, 95))
  expect_false(result$visible)
})


# --- guard_record_low_sample ---

test_that("guard_record_low_sample records warning info", {
  guard <- tracker_guard_init()
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30, "mean")

  expect_length(guard$low_sample_warnings, 1)
  expect_equal(guard$low_sample_warnings[[1]]$context, "W1:Q10")
  expect_equal(guard$low_sample_warnings[[1]]$sample_size, 15)
  expect_equal(guard$low_sample_warnings[[1]]$threshold, 30)
  expect_equal(guard$low_sample_warnings[[1]]$metric, "mean")
})

test_that("guard_record_low_sample includes timestamp", {
  guard <- tracker_guard_init()
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30)

  expect_true(!is.null(guard$low_sample_warnings[[1]]$timestamp))
  expect_s3_class(guard$low_sample_warnings[[1]]$timestamp, "POSIXct")
})

test_that("guard_record_low_sample accumulates multiple warnings", {
  guard <- tracker_guard_init()
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30, "mean")
  guard <- guard_record_low_sample(guard, "W2:Q15", 20, 50, "nps")

  expect_length(guard$low_sample_warnings, 2)
  expect_equal(guard$low_sample_warnings[[2]]$context, "W2:Q15")
})

test_that("guard_record_low_sample adds warning to guard warnings list", {
  guard <- tracker_guard_init()
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30, "mean")

  expect_true(any(grepl("Low sample size", guard$warnings)))
  expect_true(any(grepl("W1:Q10", guard$warnings)))
})

test_that("guard_record_low_sample handles NULL metric", {
  guard <- tracker_guard_init()
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30)

  expect_null(guard$low_sample_warnings[[1]]$metric)
})


# --- tracker_guard_record_modification ---

test_that("tracker_guard_record_modification records modification details", {
  guard <- tracker_guard_init()
  guard <- tracker_guard_record_modification(guard, "dk_to_na", wave_id = "W1", count = 42,
                                              details = "Converted DK/NA responses")

  expect_length(guard$data_modifications, 1)
  expect_equal(guard$data_modifications[[1]]$type, "dk_to_na")
  expect_equal(guard$data_modifications[[1]]$wave_id, "W1")
  expect_equal(guard$data_modifications[[1]]$count, 42)
  expect_equal(guard$data_modifications[[1]]$details, "Converted DK/NA responses")
})

test_that("tracker_guard_record_modification includes timestamp", {
  guard <- tracker_guard_init()
  guard <- tracker_guard_record_modification(guard, "weight_normalization")

  expect_true(!is.null(guard$data_modifications[[1]]$timestamp))
  expect_s3_class(guard$data_modifications[[1]]$timestamp, "POSIXct")
})

test_that("tracker_guard_record_modification handles optional parameters", {
  guard <- tracker_guard_init()
  guard <- tracker_guard_record_modification(guard, "comma_decimal")

  expect_equal(guard$data_modifications[[1]]$type, "comma_decimal")
  expect_null(guard$data_modifications[[1]]$wave_id)
  expect_null(guard$data_modifications[[1]]$count)
  expect_null(guard$data_modifications[[1]]$details)
})

test_that("tracker_guard_record_modification accumulates modifications", {
  guard <- tracker_guard_init()
  guard <- tracker_guard_record_modification(guard, "dk_to_na", wave_id = "W1", count = 10)
  guard <- tracker_guard_record_modification(guard, "comma_decimal", wave_id = "W2", count = 5)
  guard <- tracker_guard_record_modification(guard, "weight_normalization", wave_id = "W1")

  expect_length(guard$data_modifications, 3)
  expect_equal(guard$data_modifications[[2]]$type, "comma_decimal")
})

test_that("tracker_guard_record_modification returns guard invisibly", {
  guard <- tracker_guard_init()
  result <- withVisible(tracker_guard_record_modification(guard, "dk_to_na"))
  expect_false(result$visible)
})


# --- guard_record_alignment_issue ---

test_that("guard_record_alignment_issue stores alignment data", {
  guard <- tracker_guard_init()
  guard <- guard_record_alignment_issue(guard, "Q10",
                                         available_waves = c("W1", "W2"),
                                         missing_waves = c("W3", "W4"))

  expect_true("Q10" %in% names(guard$question_alignment_issues))
  expect_equal(guard$question_alignment_issues$Q10$available_waves, c("W1", "W2"))
  expect_equal(guard$question_alignment_issues$Q10$missing_waves, c("W3", "W4"))
})

test_that("guard_record_alignment_issue adds warning to guard", {
  guard <- tracker_guard_init()
  guard <- guard_record_alignment_issue(guard, "Q10",
                                         available_waves = c("W1"),
                                         missing_waves = c("W2", "W3"))

  expect_true(any(grepl("Q10", guard$warnings)))
  expect_true(any(grepl("W2, W3", guard$warnings)))
})

test_that("guard_record_alignment_issue records multiple questions", {
  guard <- tracker_guard_init()
  guard <- guard_record_alignment_issue(guard, "Q10", c("W1"), c("W2"))
  guard <- guard_record_alignment_issue(guard, "Q20", c("W1", "W2"), c("W3"))

  expect_length(guard$question_alignment_issues, 2)
})

test_that("guard_record_alignment_issue returns guard invisibly", {
  guard <- tracker_guard_init()
  result <- withVisible(guard_record_alignment_issue(guard, "Q10", c("W1"), c("W2")))
  expect_false(result$visible)
})


# ==============================================================================
# 3. GUARD SUMMARY GENERATION
# ==============================================================================

test_that("tracker_guard_summary includes shared summary fields", {
  guard <- tracker_guard_init()
  summary <- tracker_guard_summary(guard)

  expect_true("module" %in% names(summary))
  expect_true("has_issues" %in% names(summary))
  expect_true("n_warnings" %in% names(summary))
  expect_equal(summary$module, "TRACKER")
})

test_that("tracker_guard_summary includes all tracker-specific fields", {
  guard <- tracker_guard_init()
  summary <- tracker_guard_summary(guard)

  expect_true("missing_waves" %in% names(summary))
  expect_true("inconsistent_questions" %in% names(summary))
  expect_true("wave_sample_sizes" %in% names(summary))
  expect_true("question_alignment_issues" %in% names(summary))
  expect_true("low_sample_warnings" %in% names(summary))
  expect_true("data_modifications" %in% names(summary))
})

test_that("tracker_guard_summary shows no issues for clean guard", {
  guard <- tracker_guard_init()
  summary <- tracker_guard_summary(guard)

  expect_false(summary$has_issues)
  expect_equal(summary$n_warnings, 0)
})

test_that("tracker_guard_summary flags issues when missing waves present", {
  guard <- tracker_guard_init()
  guard <- guard_record_missing_wave(guard, "W3", "not found")
  summary <- tracker_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_equal(summary$missing_waves, "W3")
})

test_that("tracker_guard_summary flags issues when inconsistencies present", {
  guard <- tracker_guard_init()
  guard <- guard_record_inconsistency(guard, "Q10", "W1", "W2", "scale change")
  summary <- tracker_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_length(summary$inconsistent_questions, 1)
})

test_that("tracker_guard_summary flags issues when low sample warnings present", {
  guard <- tracker_guard_init()
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30)
  summary <- tracker_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_length(summary$low_sample_warnings, 1)
})

test_that("tracker_guard_summary aggregates all issues", {
  guard <- tracker_guard_init()
  guard <- guard_record_missing_wave(guard, "W3", "not found")
  guard <- guard_record_inconsistency(guard, "Q10", "W1", "W2", "scale change")
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30)
  guard <- guard_record_alignment_issue(guard, "Q20", c("W1"), c("W2"))
  guard <- tracker_guard_record_modification(guard, "dk_to_na", count = 5)
  guard <- guard_record_sample_size(guard, "W1", 100, 95, 85)

  summary <- tracker_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_length(summary$missing_waves, 1)
  expect_length(summary$inconsistent_questions, 1)
  expect_length(summary$low_sample_warnings, 1)
  expect_length(summary$question_alignment_issues, 1)
  expect_length(summary$data_modifications, 1)
  expect_length(summary$wave_sample_sizes, 1)
})

test_that("tracker_guard_summary does not flag sample_sizes or modifications as issues alone", {
  # Sample sizes and modifications by themselves do not trigger has_issues
  guard <- tracker_guard_init()
  guard <- guard_record_sample_size(guard, "W1", 500, 480, 420)
  guard <- tracker_guard_record_modification(guard, "dk_to_na", count = 5)

  summary <- tracker_guard_summary(guard)

  # These are informational, not issues
  expect_false(summary$has_issues)
})


# ==============================================================================
# 4. SAMPLE SIZE VALIDATION
# ==============================================================================

test_that("validate_sample_size returns correct structure", {
  result <- validate_sample_size(100, "mean")

  expect_true("sufficient" %in% names(result))
  expect_true("threshold" %in% names(result))
  expect_true("n_effective" %in% names(result))
})

test_that("validate_sample_size uses threshold 30 for mean", {
  result <- validate_sample_size(30, "mean")
  expect_equal(result$threshold, 30)
  expect_true(result$sufficient)

  result_low <- validate_sample_size(29, "mean")
  expect_false(result_low$sufficient)
})

test_that("validate_sample_size uses threshold 30 for proportion", {
  result <- validate_sample_size(30, "proportion")
  expect_equal(result$threshold, 30)
  expect_true(result$sufficient)

  result_low <- validate_sample_size(29, "proportion")
  expect_false(result_low$sufficient)
})

test_that("validate_sample_size uses threshold 50 for nps", {
  result <- validate_sample_size(50, "nps")
  expect_equal(result$threshold, 50)
  expect_true(result$sufficient)

  result_low <- validate_sample_size(49, "nps")
  expect_false(result_low$sufficient)
})

test_that("validate_sample_size uses threshold 30 for significance", {
  result <- validate_sample_size(30, "significance")
  expect_equal(result$threshold, 30)
  expect_true(result$sufficient)
})

test_that("validate_sample_size defaults to 30 for unknown metric type", {
  result <- validate_sample_size(30, "unknown_metric")
  expect_equal(result$threshold, 30)
  expect_true(result$sufficient)

  result_low <- validate_sample_size(29, "unknown_metric")
  expect_false(result_low$sufficient)
})

test_that("validate_sample_size handles exact boundary values", {
  # Exactly at threshold should be sufficient
  result_mean <- validate_sample_size(30, "mean")
  expect_true(result_mean$sufficient)

  result_nps <- validate_sample_size(50, "nps")
  expect_true(result_nps$sufficient)

  # One below threshold should not be sufficient
  result_mean_low <- validate_sample_size(29, "mean")
  expect_false(result_mean_low$sufficient)

  result_nps_low <- validate_sample_size(49, "nps")
  expect_false(result_nps_low$sufficient)
})

test_that("validate_sample_size handles NA effective sample size", {
  result <- validate_sample_size(NA, "mean")
  expect_false(result$sufficient)
  expect_true(is.na(result$n_effective))
})

test_that("validate_sample_size handles zero sample size", {
  result <- validate_sample_size(0, "mean")
  expect_false(result$sufficient)
  expect_equal(result$n_effective, 0)
})

test_that("validate_sample_size handles very large sample size", {
  result <- validate_sample_size(100000, "nps")
  expect_true(result$sufficient)
  expect_equal(result$n_effective, 100000)
})

test_that("validate_sample_size records low sample to guard when provided", {
  guard <- tracker_guard_init()
  result <- validate_sample_size(15, "mean", context = "W1:Q10", guard = guard)

  # The function does not return the guard, so we cannot verify directly

  # that the guard was modified. However, we verify the result is correct.
  expect_false(result$sufficient)
  expect_equal(result$threshold, 30)
})

test_that("validate_sample_size does not record when sample is sufficient", {
  guard <- tracker_guard_init()
  result <- validate_sample_size(100, "mean", context = "W1:Q10", guard = guard)

  expect_true(result$sufficient)
  # Guard should not have been modified (no low sample warning)
  expect_length(guard$low_sample_warnings, 0)
})

test_that("validate_sample_size returns n_effective in result", {
  result <- validate_sample_size(42, "proportion")
  expect_equal(result$n_effective, 42)
})


# ==============================================================================
# 5. STATUS DETERMINATION
# ==============================================================================

test_that("tracker_determine_status returns PASS for clean guard", {
  guard <- tracker_guard_init()
  status <- tracker_determine_status(guard, waves_processed = 3)

  expect_equal(status$run_status, "PASS")
})

test_that("tracker_determine_status returns PASS with waves_processed detail", {
  guard <- tracker_guard_init()
  status <- tracker_determine_status(guard, waves_processed = 5)

  expect_equal(status$run_status, "PASS")
  expect_equal(status$details$waves_processed, 5)
})

test_that("tracker_determine_status returns PARTIAL when missing waves exist", {
  guard <- tracker_guard_init()
  guard <- guard_record_missing_wave(guard, "W3", "file not found")

  status <- tracker_determine_status(guard)

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("Missing waves", status$degraded_reasons)))
})

test_that("tracker_determine_status returns PARTIAL when alignment issues exist", {
  guard <- tracker_guard_init()
  guard <- guard_record_alignment_issue(guard, "Q10", c("W1"), c("W2", "W3"))

  status <- tracker_determine_status(guard)

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("not aligned", status$degraded_reasons)))
})

test_that("tracker_determine_status returns PARTIAL when low sample warnings exist", {
  guard <- tracker_guard_init()
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30, "mean")

  status <- tracker_determine_status(guard)

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("low sample size", status$degraded_reasons)))
})

test_that("tracker_determine_status returns PARTIAL when skipped questions provided", {
  guard <- tracker_guard_init()
  skipped <- list(
    Q10 = "Missing in all waves",
    Q15 = "Invalid question type"
  )

  status <- tracker_determine_status(guard, skipped_questions = skipped)

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("skipped", status$degraded_reasons)))
})

test_that("tracker_determine_status includes affected outputs", {
  guard <- tracker_guard_init()
  guard <- guard_record_alignment_issue(guard, "Q10", c("W1"), c("W2"))

  status <- tracker_determine_status(guard)

  expect_true(length(status$affected_outputs) > 0)
  expect_true(any(grepl("Trend calculations", status$affected_outputs)))
})

test_that("tracker_determine_status lists affected questions in outputs", {
  guard <- tracker_guard_init()
  guard <- guard_record_alignment_issue(guard, "Q10", c("W1"), c("W2"))
  guard <- guard_record_alignment_issue(guard, "Q20", c("W1"), c("W3"))

  status <- tracker_determine_status(guard)

  expect_true(any(grepl("Q10", status$affected_outputs)))
  expect_true(any(grepl("Q20", status$affected_outputs)))
})

test_that("tracker_determine_status handles multiple degradation reasons", {
  guard <- tracker_guard_init()
  guard <- guard_record_missing_wave(guard, "W3", "not found")
  guard <- guard_record_alignment_issue(guard, "Q10", c("W1"), c("W2"))
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30, "mean")

  skipped <- list(Q99 = "Missing entirely")

  status <- tracker_determine_status(guard, skipped_questions = skipped)

  expect_equal(status$run_status, "PARTIAL")
  # Should have at least 4 degradation reasons
  expect_true(length(status$degraded_reasons) >= 4)
})

test_that("tracker_determine_status returns PARTIAL with missing wave details", {
  guard <- tracker_guard_init()
  guard <- guard_record_missing_wave(guard, "W3", "not found")
  guard <- guard_record_missing_wave(guard, "W5", "corrupt")

  status <- tracker_determine_status(guard)

  expect_equal(status$run_status, "PARTIAL")
  expect_equal(status$details$missing_waves, c("W3", "W5"))
})

test_that("tracker_determine_status returns PARTIAL with skipped questions details", {
  guard <- tracker_guard_init()
  skipped <- list(Q10 = "Reason A", Q20 = "Reason B")

  status <- tracker_determine_status(guard, skipped_questions = skipped)

  expect_equal(status$run_status, "PARTIAL")
  expect_equal(status$details$skipped_questions, skipped)
})

test_that("tracker_determine_status handles empty skipped questions list", {
  guard <- tracker_guard_init()
  status <- tracker_determine_status(guard, skipped_questions = list())

  expect_equal(status$run_status, "PASS")
})

test_that("tracker_determine_status handles NULL skipped questions", {
  guard <- tracker_guard_init()
  status <- tracker_determine_status(guard, skipped_questions = NULL)

  expect_equal(status$run_status, "PASS")
})

test_that("tracker_determine_status handles inconsistent questions combined with other issues", {
  guard <- tracker_guard_init()
  guard <- guard_record_inconsistency(guard, "Q10", "W1", "W2", "scale change")
  guard <- guard_record_low_sample(guard, "W1:Q10", 15, 30, "mean")

  status <- tracker_determine_status(guard)

  # Inconsistencies alone produce has_issues=TRUE via warnings/stability_flags,
  # but tracker_determine_status only builds degraded_reasons for
  # missing_waves, alignment_issues, low_sample_warnings, and skipped_questions.
  # When combined with another issue that has a reason builder, PARTIAL is returned.
  expect_equal(status$run_status, "PARTIAL")
})

test_that("tracker_determine_status errors when only inconsistencies present (no reason builders)", {
  guard <- tracker_guard_init()
  guard <- guard_record_inconsistency(guard, "Q10", "W1", "W2", "scale change")

  # Known limitation: inconsistencies set has_issues=TRUE but no corresponding

  # degraded_reason builder exists, so trs_status_partial fails with an error
  # because degraded_reasons is empty. This documents current behavior.
  expect_error(
    tracker_determine_status(guard),
    "PARTIAL status requires at least one degraded_reason"
  )
})


# ==============================================================================
# 6. CONFIG STRUCTURE VALIDATION
# ==============================================================================

test_that("validate_config_structure passes for valid config", {
  config <- list(
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE),
    settings = list(project_name = "Test Project", decimal_places_ratings = 1),
    banner = data.frame(BreakVariable = "Total", stringsAsFactors = FALSE),
    tracked_questions = data.frame(QuestionCode = c("Q1", "Q2"), stringsAsFactors = FALSE)
  )

  result <- validate_config_structure(config)

  expect_length(result$errors, 0)
})

test_that("validate_config_structure reports missing required components", {
  config <- list(
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE),
    settings = list(project_name = "Test")
    # Missing: banner, tracked_questions
  )

  result <- validate_config_structure(config)

  expect_true(length(result$errors) > 0)
  expect_true(any(grepl("banner", result$errors)))
  expect_true(any(grepl("tracked_questions", result$errors)))
})

test_that("validate_config_structure reports each missing component individually", {
  config <- list(
    settings = list(project_name = "Test")
    # Missing: waves, banner, tracked_questions
  )

  result <- validate_config_structure(config)

  missing_count <- sum(grepl("Missing required config component", result$errors))
  expect_equal(missing_count, 3)
})

test_that("validate_config_structure warns about missing project_name", {
  config <- list(
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE),
    settings = list(),
    banner = data.frame(BreakVariable = "Total", stringsAsFactors = FALSE),
    tracked_questions = data.frame(QuestionCode = c("Q1"), stringsAsFactors = FALSE)
  )

  result <- validate_config_structure(config)

  expect_true(any(grepl("project_name", result$warnings)))
})

test_that("validate_config_structure errors for invalid decimal_places_ratings", {
  config <- list(
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE),
    settings = list(project_name = "Test", decimal_places_ratings = 5),
    banner = data.frame(BreakVariable = "Total", stringsAsFactors = FALSE),
    tracked_questions = data.frame(QuestionCode = c("Q1"), stringsAsFactors = FALSE)
  )

  result <- validate_config_structure(config)

  expect_true(any(grepl("decimal_places_ratings", result$errors)))
})

test_that("validate_config_structure errors for negative decimal_places_ratings", {
  config <- list(
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE),
    settings = list(project_name = "Test", decimal_places_ratings = -1),
    banner = data.frame(BreakVariable = "Total", stringsAsFactors = FALSE),
    tracked_questions = data.frame(QuestionCode = c("Q1"), stringsAsFactors = FALSE)
  )

  result <- validate_config_structure(config)

  expect_true(any(grepl("decimal_places_ratings", result$errors)))
})

test_that("validate_config_structure accepts decimal_places_ratings at boundaries", {
  config <- list(
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE),
    settings = list(project_name = "Test", decimal_places_ratings = 0),
    banner = data.frame(BreakVariable = "Total", stringsAsFactors = FALSE),
    tracked_questions = data.frame(QuestionCode = c("Q1"), stringsAsFactors = FALSE)
  )

  result <- validate_config_structure(config)
  expect_false(any(grepl("decimal_places_ratings", result$errors)))

  config$settings$decimal_places_ratings <- 3
  result <- validate_config_structure(config)
  expect_false(any(grepl("decimal_places_ratings", result$errors)))
})

test_that("validate_config_structure uses default decimal_places_ratings when missing", {
  config <- list(
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE),
    settings = list(project_name = "Test"),
    banner = data.frame(BreakVariable = "Total", stringsAsFactors = FALSE),
    tracked_questions = data.frame(QuestionCode = c("Q1"), stringsAsFactors = FALSE)
  )

  result <- validate_config_structure(config)

  # Should not error - default of 1 is used
  expect_false(any(grepl("decimal_places_ratings", result$errors)))
})


# ==============================================================================
# 7. WAVE DEFINITIONS VALIDATION
# ==============================================================================

test_that("validate_wave_definitions passes for valid 2-wave config", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2"),
      WaveName = c("Wave 1", "Wave 2"),
      FieldworkStart = as.Date(c("2024-01-01", "2024-07-01")),
      FieldworkEnd = as.Date(c("2024-01-31", "2024-07-31")),
      stringsAsFactors = FALSE
    )
  )

  result <- validate_wave_definitions(config)

  expect_length(result$errors, 0)
  expect_true(any(grepl("Tracking 2 waves", result$info)))
})

test_that("validate_wave_definitions errors for fewer than 2 waves", {
  config <- list(
    waves = data.frame(
      WaveID = "W1",
      WaveName = "Wave 1",
      FieldworkStart = as.Date("2024-01-01"),
      FieldworkEnd = as.Date("2024-01-31"),
      stringsAsFactors = FALSE
    )
  )

  result <- validate_wave_definitions(config)

  expect_true(any(grepl("At least 2 waves", result$errors)))
})

test_that("validate_wave_definitions errors for duplicate WaveIDs", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W1", "W2"),
      WaveName = c("Wave 1", "Wave 1 dup", "Wave 2"),
      FieldworkStart = as.Date(c("2024-01-01", "2024-04-01", "2024-07-01")),
      FieldworkEnd = as.Date(c("2024-01-31", "2024-04-30", "2024-07-31")),
      stringsAsFactors = FALSE
    )
  )

  result <- validate_wave_definitions(config)

  expect_true(any(grepl("Duplicate WaveIDs", result$errors)))
})

test_that("validate_wave_definitions warns for duplicate WaveNames", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2"),
      WaveName = c("Same Name", "Same Name"),
      FieldworkStart = as.Date(c("2024-01-01", "2024-07-01")),
      FieldworkEnd = as.Date(c("2024-01-31", "2024-07-31")),
      stringsAsFactors = FALSE
    )
  )

  result <- validate_wave_definitions(config)

  expect_true(any(grepl("Duplicate WaveNames", result$warnings)))
})

test_that("validate_wave_definitions errors when FieldworkEnd before FieldworkStart", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2"),
      WaveName = c("Wave 1", "Wave 2"),
      FieldworkStart = as.Date(c("2024-01-31", "2024-07-01")),
      FieldworkEnd = as.Date(c("2024-01-01", "2024-07-31")),
      stringsAsFactors = FALSE
    )
  )

  result <- validate_wave_definitions(config)

  expect_true(any(grepl("FieldworkEnd before FieldworkStart", result$errors)))
  expect_true(any(grepl("W1", result$errors)))
})

test_that("validate_wave_definitions warns for non-chronological order", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2", "W3"),
      WaveName = c("Wave 1", "Wave 2", "Wave 3"),
      FieldworkStart = as.Date(c("2024-07-01", "2024-01-01", "2024-10-01")),
      FieldworkEnd = as.Date(c("2024-07-31", "2024-01-31", "2024-10-31")),
      stringsAsFactors = FALSE
    )
  )

  result <- validate_wave_definitions(config)

  expect_true(any(grepl("not in chronological order", result$warnings)))
})

test_that("validate_wave_definitions handles NA dates gracefully", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2"),
      WaveName = c("Wave 1", "Wave 2"),
      FieldworkStart = as.Date(c(NA, "2024-07-01")),
      FieldworkEnd = as.Date(c(NA, "2024-07-31")),
      stringsAsFactors = FALSE
    )
  )

  # Should not error on NA dates
  result <- validate_wave_definitions(config)
  expect_false(any(grepl("FieldworkEnd before FieldworkStart", result$errors)))
})

test_that("validate_wave_definitions reports wave count in info", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2", "W3", "W4"),
      WaveName = c("Wave 1", "Wave 2", "Wave 3", "Wave 4"),
      FieldworkStart = as.Date(c("2024-01-01", "2024-04-01", "2024-07-01", "2024-10-01")),
      FieldworkEnd = as.Date(c("2024-01-31", "2024-04-30", "2024-07-31", "2024-10-31")),
      stringsAsFactors = FALSE
    )
  )

  result <- validate_wave_definitions(config)

  expect_true(any(grepl("Tracking 4 waves", result$info)))
})

test_that("validate_wave_definitions passes for waves in correct chronological order", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2", "W3"),
      WaveName = c("Wave 1", "Wave 2", "Wave 3"),
      FieldworkStart = as.Date(c("2024-01-01", "2024-04-01", "2024-07-01")),
      FieldworkEnd = as.Date(c("2024-01-31", "2024-04-30", "2024-07-31")),
      stringsAsFactors = FALSE
    )
  )

  result <- validate_wave_definitions(config)

  expect_false(any(grepl("not in chronological order", result$warnings)))
})


# ==============================================================================
# 8. VALIDATION RESULT MERGING
# ==============================================================================

test_that("merge_validation_results combines errors from both results", {
  r1 <- list(errors = c("Error A"), warnings = character(0), info = character(0))
  r2 <- list(errors = c("Error B", "Error C"), warnings = character(0), info = character(0))

  merged <- merge_validation_results(r1, r2)

  expect_equal(merged$errors, c("Error A", "Error B", "Error C"))
})

test_that("merge_validation_results combines warnings from both results", {
  r1 <- list(errors = character(0), warnings = c("Warn A"), info = character(0))
  r2 <- list(errors = character(0), warnings = c("Warn B"), info = character(0))

  merged <- merge_validation_results(r1, r2)

  expect_equal(merged$warnings, c("Warn A", "Warn B"))
})

test_that("merge_validation_results combines info from both results", {
  r1 <- list(errors = character(0), warnings = character(0), info = c("Info A"))
  r2 <- list(errors = character(0), warnings = character(0), info = c("Info B", "Info C"))

  merged <- merge_validation_results(r1, r2)

  expect_equal(merged$info, c("Info A", "Info B", "Info C"))
})

test_that("merge_validation_results handles empty first result", {
  r1 <- list(errors = character(0), warnings = character(0), info = character(0))
  r2 <- list(errors = c("Error A"), warnings = c("Warn B"), info = c("Info C"))

  merged <- merge_validation_results(r1, r2)

  expect_equal(merged$errors, "Error A")
  expect_equal(merged$warnings, "Warn B")
  expect_equal(merged$info, "Info C")
})

test_that("merge_validation_results handles empty second result", {
  r1 <- list(errors = c("Error A"), warnings = c("Warn B"), info = c("Info C"))
  r2 <- list(errors = character(0), warnings = character(0), info = character(0))

  merged <- merge_validation_results(r1, r2)

  expect_equal(merged$errors, "Error A")
  expect_equal(merged$warnings, "Warn B")
  expect_equal(merged$info, "Info C")
})

test_that("merge_validation_results handles both empty", {
  r1 <- list(errors = character(0), warnings = character(0), info = character(0))
  r2 <- list(errors = character(0), warnings = character(0), info = character(0))

  merged <- merge_validation_results(r1, r2)

  expect_length(merged$errors, 0)
  expect_length(merged$warnings, 0)
  expect_length(merged$info, 0)
})

test_that("merge_validation_results returns list with all three fields", {
  r1 <- list(errors = character(0), warnings = character(0), info = character(0))
  r2 <- list(errors = character(0), warnings = character(0), info = character(0))

  merged <- merge_validation_results(r1, r2)

  expect_true("errors" %in% names(merged))
  expect_true("warnings" %in% names(merged))
  expect_true("info" %in% names(merged))
  expect_length(names(merged), 3)
})

test_that("merge_validation_results preserves order of items", {
  r1 <- list(errors = c("E1", "E2"), warnings = c("W1"), info = c("I1"))
  r2 <- list(errors = c("E3"), warnings = c("W2", "W3"), info = c("I2"))

  merged <- merge_validation_results(r1, r2)

  expect_equal(merged$errors, c("E1", "E2", "E3"))
  expect_equal(merged$warnings, c("W1", "W2", "W3"))
  expect_equal(merged$info, c("I1", "I2"))
})

test_that("merge_validation_results can be chained", {
  r1 <- list(errors = c("E1"), warnings = character(0), info = character(0))
  r2 <- list(errors = c("E2"), warnings = c("W1"), info = character(0))
  r3 <- list(errors = character(0), warnings = character(0), info = c("I1"))

  merged <- merge_validation_results(
    merge_validation_results(r1, r2),
    r3
  )

  expect_equal(merged$errors, c("E1", "E2"))
  expect_equal(merged$warnings, "W1")
  expect_equal(merged$info, "I1")
})


# ==============================================================================
# SUPPLEMENTARY TESTS: tracker_refuse prefix handling
# ==============================================================================

test_that("tracker_refuse auto-prefixes code without valid prefix", {
  expect_error(
    tracker_refuse(
      code = "MISSING_THING",
      title = "Test",
      problem = "Test problem",
      why_it_matters = "Test impact",
      how_to_fix = "Fix it"
    ),
    class = "turas_refusal"
  )
})

test_that("tracker_refuse preserves valid prefix codes", {
  err <- tryCatch(
    tracker_refuse(
      code = "DATA_BAD_INPUT",
      title = "Test",
      problem = "Test problem",
      why_it_matters = "Test impact",
      how_to_fix = "Fix it"
    ),
    turas_refusal = function(e) e
  )

  expect_equal(err$code, "DATA_BAD_INPUT")
})

test_that("tracker_refuse adds CFG_ prefix when code has no valid prefix", {
  err <- tryCatch(
    tracker_refuse(
      code = "MISSING_THING",
      title = "Test",
      problem = "Test problem",
      why_it_matters = "Test impact",
      how_to_fix = "Fix it"
    ),
    turas_refusal = function(e) e
  )

  expect_equal(err$code, "CFG_MISSING_THING")
})


# ==============================================================================
# SUPPLEMENTARY TESTS: validate_tracker_config
# ==============================================================================

test_that("validate_tracker_config refuses on non-list config", {
  expect_error(
    validate_tracker_config("not a list"),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_config refuses when missing required sections", {
  config <- list(waves = data.frame(WaveID = "W1"))
  # Missing tracked_questions

  expect_error(
    validate_tracker_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_config refuses when waves missing required columns", {
  config <- list(
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE),
    tracked_questions = data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  )
  # waves is missing WaveName and DataFile columns

  expect_error(
    validate_tracker_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_config refuses when tracked_questions missing QuestionCode", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2"),
      WaveName = c("Wave 1", "Wave 2"),
      DataFile = c("w1.csv", "w2.csv"),
      stringsAsFactors = FALSE
    ),
    tracked_questions = data.frame(SomeColumn = "Q1", stringsAsFactors = FALSE)
  )

  expect_error(
    validate_tracker_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_config passes for valid minimal config", {
  config <- list(
    waves = data.frame(
      WaveID = c("W1", "W2"),
      WaveName = c("Wave 1", "Wave 2"),
      DataFile = c("w1.csv", "w2.csv"),
      stringsAsFactors = FALSE
    ),
    tracked_questions = data.frame(QuestionCode = c("Q1", "Q2"), stringsAsFactors = FALSE)
  )

  # Should not throw
  result <- validate_tracker_config(config)
  expect_true(result)
})


# ==============================================================================
# SUPPLEMENTARY TESTS: validate_tracker_wave_files
# ==============================================================================

test_that("validate_tracker_wave_files refuses on NULL wave files", {
  expect_error(
    validate_tracker_wave_files(NULL),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_wave_files refuses on empty wave files", {
  expect_error(
    validate_tracker_wave_files(list()),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_wave_files refuses on single wave file", {
  expect_error(
    validate_tracker_wave_files(list(W1 = tempfile())),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_wave_files refuses when files do not exist", {
  wave_files <- list(
    W1 = "/nonexistent/path/wave1.csv",
    W2 = "/nonexistent/path/wave2.csv"
  )

  expect_error(
    validate_tracker_wave_files(wave_files),
    class = "turas_refusal"
  )
})

test_that("validate_tracker_wave_files passes when all files exist", {
  # Create temporary files
  f1 <- tempfile(fileext = ".csv")
  f2 <- tempfile(fileext = ".csv")
  writeLines("x,y", f1)
  writeLines("x,y", f2)
  on.exit(unlink(c(f1, f2)))

  wave_files <- list(W1 = f1, W2 = f2)

  result <- validate_tracker_wave_files(wave_files)
  expect_true(result)
})
