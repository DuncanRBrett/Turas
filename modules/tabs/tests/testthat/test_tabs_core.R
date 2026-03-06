# ==============================================================================
# TABS MODULE - CORE UNIT TESTS
# ==============================================================================
#
# Tests for the tabs module's guard layer, config loading, and validation
# functions. Covers:
#   1. Guard state initialization and manipulation
#   2. Question skip / empty base recording
#   3. Guard summary generation with has_issues flag
#   4. Status determination logic (PASS / PARTIAL / REFUSE thresholds)
#   5. Type conversion utilities (safe_logical, safe_numeric)
#   6. Config value retrieval with defaults and required flag
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_tabs_core.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================
# Detect project root so tests work from any working directory.

detect_turas_root <- function() {
  # 1. TURAS_HOME environment variable

  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }

  # 2. Walk up from this file's location (when sourced via testthat)
  candidates <- c(
    getwd(),
    # Common invocation patterns
    file.path(getwd(), "../.."),       # from modules/tabs/tests/testthat
    file.path(getwd(), "../../.."),    # from modules/tabs/tests
    file.path(getwd(), "../../../..") # deeper nesting
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

# Source shared TRS infrastructure first
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))

# Source tabs guard layer
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))

# Source tabs config_loader (for safe_logical, safe_numeric, get_config_value)
source(file.path(turas_root, "modules/tabs/lib/config_loader.R"))


# ==============================================================================
# 1. GUARD STATE INITIALIZATION
# ==============================================================================

context("Guard State Initialization")

test_that("tabs_guard_init returns a properly structured guard state", {
  guard <- tabs_guard_init()

  # Core TRS guard fields
  expect_equal(guard$module, "TABS")
  expect_type(guard$warnings, "character")
  expect_length(guard$warnings, 0)
  expect_type(guard$soft_failures, "list")
  expect_length(guard$soft_failures, 0)

  # Tabs-specific fields

  expect_type(guard$skipped_questions, "character")
  expect_length(guard$skipped_questions, 0)
  expect_type(guard$empty_base_questions, "character")
  expect_length(guard$empty_base_questions, 0)
  expect_type(guard$banner_issues, "list")
  expect_length(guard$banner_issues, 0)
  expect_type(guard$option_mapping_issues, "list")
  expect_length(guard$option_mapping_issues, 0)
})

test_that("tabs_guard_init returns a trs_guard_state class object", {
  guard <- tabs_guard_init()
  expect_s3_class(guard, "trs_guard_state")
})

test_that("tabs_guard_init includes a timestamp", {
  guard <- tabs_guard_init()
  expect_true(inherits(guard$timestamp, "POSIXct"))
})


# ==============================================================================
# 2. QUESTION SKIP AND EMPTY BASE RECORDING
# ==============================================================================

context("Question Skip and Empty Base Recording")

test_that("guard_record_skipped_question adds question code to skipped list", {
  guard <- tabs_guard_init()
  guard <- guard_record_skipped_question(guard, "Q1", "Column not found")

  expect_equal(guard$skipped_questions, "Q1")
  expect_length(guard$warnings, 1)
  expect_true(grepl("Q1", guard$warnings[1]))
  expect_true(grepl("Column not found", guard$warnings[1]))
})

test_that("guard_record_skipped_question accumulates multiple skipped questions", {
  guard <- tabs_guard_init()
  guard <- guard_record_skipped_question(guard, "Q1", "Missing column")
  guard <- guard_record_skipped_question(guard, "Q5", "No valid responses")
  guard <- guard_record_skipped_question(guard, "Q10", "Unsupported type")

  expect_equal(guard$skipped_questions, c("Q1", "Q5", "Q10"))
  expect_length(guard$warnings, 3)
})

test_that("guard_record_skipped_question creates warnings in 'skipped' category", {
  guard <- tabs_guard_init()
  guard <- guard_record_skipped_question(guard, "Q1", "Test reason")

  expect_true("skipped" %in% names(guard$soft_failures))
  expect_length(guard$soft_failures$skipped, 1)
})

test_that("guard_record_empty_base adds question code to empty base list", {
  guard <- tabs_guard_init()
  guard <- guard_record_empty_base(guard, "Q3")

  expect_equal(guard$empty_base_questions, "Q3")
  expect_length(guard$warnings, 1)
  expect_true(grepl("Q3", guard$warnings[1]))
})

test_that("guard_record_empty_base includes filter expression when provided", {
  guard <- tabs_guard_init()
  guard <- guard_record_empty_base(guard, "Q7", "age > 65")

  expect_equal(guard$empty_base_questions, "Q7")
  expect_true(grepl("age > 65", guard$warnings[1]))
})

test_that("guard_record_empty_base handles NULL filter expression", {
  guard <- tabs_guard_init()
  guard <- guard_record_empty_base(guard, "Q2", NULL)

  expect_equal(guard$empty_base_questions, "Q2")
  expect_true(grepl("Q2", guard$warnings[1]))
  # Should NOT contain "filter:" when filter is NULL
  expect_false(grepl("filter:", guard$warnings[1]))
})

test_that("guard_record_empty_base handles empty string filter expression", {
  guard <- tabs_guard_init()
  guard <- guard_record_empty_base(guard, "Q4", "")

  expect_equal(guard$empty_base_questions, "Q4")
  # nzchar("") is FALSE, so filter should not appear
  expect_false(grepl("filter:", guard$warnings[1]))
})

test_that("guard_record_empty_base accumulates multiple empty bases", {
  guard <- tabs_guard_init()
  guard <- guard_record_empty_base(guard, "Q1", "segment == 'A'")
  guard <- guard_record_empty_base(guard, "Q2", "segment == 'B'")

  expect_equal(guard$empty_base_questions, c("Q1", "Q2"))
  expect_length(guard$warnings, 2)
})

test_that("guard_record_empty_base creates warnings in 'empty_base' category", {
  guard <- tabs_guard_init()
  guard <- guard_record_empty_base(guard, "Q1", "some filter")

  expect_true("empty_base" %in% names(guard$soft_failures))
  expect_length(guard$soft_failures$empty_base, 1)
})


# ==============================================================================
# 3. GUARD SUMMARY GENERATION
# ==============================================================================

context("Guard Summary Generation")

test_that("tabs_guard_summary reports no issues for clean guard", {
  guard <- tabs_guard_init()
  summary <- tabs_guard_summary(guard)

  expect_false(summary$has_issues)
  expect_equal(summary$module, "TABS")
  expect_equal(summary$n_warnings, 0)
  expect_length(summary$skipped_questions, 0)
  expect_length(summary$empty_base_questions, 0)
  expect_length(summary$banner_issues, 0)
  expect_length(summary$option_mapping_issues, 0)
})

test_that("tabs_guard_summary sets has_issues when questions are skipped", {
  guard <- tabs_guard_init()
  guard <- guard_record_skipped_question(guard, "Q1", "Missing")
  summary <- tabs_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_equal(summary$skipped_questions, "Q1")
})

test_that("tabs_guard_summary sets has_issues when empty bases exist", {
  guard <- tabs_guard_init()
  guard <- guard_record_empty_base(guard, "Q2")
  summary <- tabs_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_equal(summary$empty_base_questions, "Q2")
})

test_that("tabs_guard_summary sets has_issues when banner issues exist", {
  guard <- tabs_guard_init()
  guard$banner_issues <- list(list(code = "B1", reason = "mismatch"))
  summary <- tabs_guard_summary(guard)

  expect_true(summary$has_issues)
})

test_that("tabs_guard_summary includes option_mapping_issues field", {
  guard <- tabs_guard_init()
  guard$option_mapping_issues <- list(list(code = "Q5", reason = "label mismatch"))
  summary <- tabs_guard_summary(guard)

  expect_length(summary$option_mapping_issues, 1)
})

test_that("tabs_guard_summary includes warnings from base guard_summary", {
  guard <- tabs_guard_init()
  guard <- guard_warn(guard, "test warning", "general")
  summary <- tabs_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_equal(summary$n_warnings, 1)
  expect_true("test warning" %in% summary$warnings)
})

test_that("tabs_guard_summary reflects stability flags from base guard", {
  guard <- tabs_guard_init()
  guard <- guard_flag_stability(guard, "Low sample size in segment X")
  summary <- tabs_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_true(summary$use_with_caution)
  expect_true("Low sample size in segment X" %in% summary$stability_flags)
})

test_that("tabs_guard_summary combines multiple issue types correctly", {
  guard <- tabs_guard_init()
  guard <- guard_record_skipped_question(guard, "Q1", "missing")
  guard <- guard_record_empty_base(guard, "Q2", "filter1")
  guard$banner_issues <- list(list(code = "B1", reason = "test"))
  guard <- guard_flag_stability(guard, "small cells")

  summary <- tabs_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_equal(summary$n_warnings, 2)  # 1 from skip + 1 from empty base
  expect_equal(summary$skipped_questions, "Q1")
  expect_equal(summary$empty_base_questions, "Q2")
  expect_length(summary$banner_issues, 1)
  expect_true(summary$use_with_caution)
})


# ==============================================================================
# 4. STATUS DETERMINATION LOGIC
# ==============================================================================

context("Status Determination (tabs_determine_status)")

# --- PASS conditions ---

test_that("tabs_determine_status returns PASS for clean run", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PASS")
  expect_equal(status$module, "TABS")
})

test_that("PASS status includes questions_processed count", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 25,
    n_questions_total = 25,
    n_respondents = 100,
    banner_columns = 5
  )

  expect_equal(status$run_status, "PASS")
  expect_equal(status$details$questions_processed, 25)
})

test_that("PASS when skip rate is at or below 20% threshold", {
  guard <- tabs_guard_init()
  # 20% skip rate (exactly at threshold - should NOT trigger PARTIAL for skip_rate)
  # But skipped_questions in guard will trigger PARTIAL via the guard summary
  # Since no guard skipped_questions are recorded, the skip rate check is purely
  # based on n_questions_processed vs n_questions_total
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 80,
    n_questions_total = 100,
    n_respondents = 200,
    banner_columns = 10
  )

  # 20/100 = 20% skip rate, threshold is > 0.20, so 20% exactly does NOT trigger
  # However, the skipped_questions guard check may still trigger PARTIAL
  # In this case guard has no skipped_questions recorded, but the math-based
  # skip check should not fire at exactly 20%
  expect_equal(status$run_status, "PASS")
})

# --- REFUSE conditions ---

test_that("tabs_determine_status returns REFUSE when error_count > 0", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12,
    error_count = 1
  )

  expect_equal(status$run_status, "REFUSE")
  expect_true(grepl("error", status$details$reason, ignore.case = TRUE))
})

test_that("tabs_determine_status returns REFUSE when n_respondents is 0", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 0,
    banner_columns = 12
  )

  expect_equal(status$run_status, "REFUSE")
  expect_equal(status$details$code, "DATA_NO_RESPONDENTS")
})

test_that("tabs_determine_status returns REFUSE when respondents below minimum", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 29,
    banner_columns = 12,
    min_respondents = 30
  )

  expect_equal(status$run_status, "REFUSE")
  expect_equal(status$details$code, "DATA_INSUFFICIENT_SAMPLE")
})

test_that("tabs_determine_status uses custom min_respondents threshold", {
  guard <- tabs_guard_init()

  # Should REFUSE at 49 with min_respondents=50
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 10,
    n_questions_total = 10,
    n_respondents = 49,
    banner_columns = 5,
    min_respondents = 50
  )
  expect_equal(status$run_status, "REFUSE")

  # Should PASS at 50 with min_respondents=50
  status2 <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 10,
    n_questions_total = 10,
    n_respondents = 50,
    banner_columns = 5,
    min_respondents = 50
  )
  expect_equal(status2$run_status, "PASS")
})

test_that("tabs_determine_status returns REFUSE when banner_columns is 0", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 0
  )

  expect_equal(status$run_status, "REFUSE")
  expect_equal(status$details$code, "CFG_NO_BANNER")
})

test_that("tabs_determine_status returns REFUSE when n_questions_processed is 0", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 0,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "REFUSE")
  expect_equal(status$details$code, "DATA_NO_QUESTIONS")
})

test_that("REFUSE conditions are checked in priority order (error first)", {
  guard <- tabs_guard_init()
  # Both error_count > 0 AND n_respondents == 0
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 0,
    n_questions_total = 50,
    n_respondents = 0,
    banner_columns = 0,
    error_count = 3
  )

  # error_count is checked first
  expect_equal(status$run_status, "REFUSE")
  expect_equal(status$details$code, "BUG_EXECUTION_ERROR")
})

# --- PARTIAL conditions ---

test_that("tabs_determine_status returns PARTIAL when skip rate exceeds 20%", {
  guard <- tabs_guard_init()
  # 21/100 = 21% skip rate, above threshold
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 79,
    n_questions_total = 100,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("skip rate", status$degraded_reasons, ignore.case = TRUE)))
  expect_true("question_coverage" %in% status$affected_outputs)
})

test_that("tabs_determine_status returns PARTIAL when guard has skipped questions", {
  guard <- tabs_guard_init()
  guard <- guard_record_skipped_question(guard, "Q1", "missing column")

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 49,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("skipped", status$degraded_reasons, ignore.case = TRUE)))
  expect_true("skipped_questions" %in% status$affected_outputs)
})

test_that("tabs_determine_status returns PARTIAL for high empty base rate", {
  guard <- tabs_guard_init()
  # Add empty bases for > 10% of total questions
  for (i in 1:15) {
    guard <- guard_record_empty_base(guard, paste0("Q", i))
  }

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 100,
    n_questions_total = 100,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("empty base", status$degraded_reasons, ignore.case = TRUE)))
  expect_true("base_sizes" %in% status$affected_outputs)
})

test_that("tabs_determine_status returns PARTIAL when banner issues exist", {
  guard <- tabs_guard_init()
  guard$banner_issues <- list(list(code = "B1", reason = "test"))

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("banner", status$degraded_reasons, ignore.case = TRUE)))
  expect_true("banner_structure" %in% status$affected_outputs)
})

test_that("tabs_determine_status returns PARTIAL when option mapping issues exist", {
  guard <- tabs_guard_init()
  guard$option_mapping_issues <- list(list(code = "Q5", reason = "label mismatch"))

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("option mapping", status$degraded_reasons, ignore.case = TRUE)))
  expect_true("option_mapping" %in% status$affected_outputs)
})

test_that("tabs_determine_status returns PARTIAL when guard is flagged unstable", {
  guard <- tabs_guard_init()
  guard <- guard_flag_stability(guard, "Small cell sizes detected")

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
  expect_true(any(grepl("unstable", status$degraded_reasons, ignore.case = TRUE)))
  expect_true("stability" %in% status$affected_outputs)
})

test_that("PARTIAL status lists multiple degradation reasons when applicable", {
  guard <- tabs_guard_init()
  guard <- guard_record_skipped_question(guard, "Q1", "missing")
  guard$banner_issues <- list(list(code = "B1", reason = "test"))
  guard <- guard_flag_stability(guard, "issue")

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
  expect_true(length(status$degraded_reasons) >= 3)
  expect_true(length(status$affected_outputs) >= 3)
})

test_that("PARTIAL status includes skipped_questions in details", {
  guard <- tabs_guard_init()
  guard <- guard_record_skipped_question(guard, "Q1", "missing")
  guard <- guard_record_skipped_question(guard, "Q2", "invalid")

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 48,
    n_questions_total = 50,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
  expect_equal(status$details$skipped_questions, c("Q1", "Q2"))
})

# --- NULL parameter handling ---

test_that("tabs_determine_status handles NULL parameters gracefully", {
  guard <- tabs_guard_init()

  # All NULLs should result in PASS (no checks triggered)
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = NULL,
    n_questions_total = NULL,
    n_respondents = NULL,
    banner_columns = NULL
  )

  expect_equal(status$run_status, "PASS")
})

test_that("tabs_determine_status handles partial NULL parameters", {
  guard <- tabs_guard_init()

  # Only respondent check applies - should PASS
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = NULL,
    n_questions_total = NULL,
    n_respondents = 100,
    banner_columns = NULL
  )

  expect_equal(status$run_status, "PASS")
})

# --- Boundary checks ---

test_that("exactly min_respondents is accepted (boundary)", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 10,
    n_questions_total = 10,
    n_respondents = 30,
    banner_columns = 5,
    min_respondents = 30
  )

  expect_equal(status$run_status, "PASS")
})

test_that("single banner column is accepted", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 10,
    n_questions_total = 10,
    n_respondents = 100,
    banner_columns = 1
  )

  expect_equal(status$run_status, "PASS")
})

test_that("single question processed is accepted", {
  guard <- tabs_guard_init()
  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 1,
    n_questions_total = 1,
    n_respondents = 100,
    banner_columns = 5
  )

  expect_equal(status$run_status, "PASS")
})


# ==============================================================================
# 5. TYPE CONVERSION UTILITIES
# ==============================================================================

context("safe_logical")

test_that("safe_logical returns TRUE for truthy values", {
  expect_true(safe_logical("Y"))
  expect_true(safe_logical("y"))
  expect_true(safe_logical("YES"))
  expect_true(safe_logical("yes"))
  expect_true(safe_logical("Yes"))
  expect_true(safe_logical("T"))
  expect_true(safe_logical("t"))
  expect_true(safe_logical("TRUE"))
  expect_true(safe_logical("true"))
  expect_true(safe_logical("True"))
  expect_true(safe_logical("1"))
  expect_true(safe_logical(1))
  expect_true(safe_logical(TRUE))
})

test_that("safe_logical returns FALSE for falsy values", {
  expect_false(safe_logical("N"))
  expect_false(safe_logical("n"))
  expect_false(safe_logical("NO"))
  expect_false(safe_logical("no"))
  expect_false(safe_logical("No"))
  expect_false(safe_logical("F"))
  expect_false(safe_logical("f"))
  expect_false(safe_logical("FALSE"))
  expect_false(safe_logical("false"))
  expect_false(safe_logical("False"))
  expect_false(safe_logical("0"))
  expect_false(safe_logical(0))
  expect_false(safe_logical(FALSE))
})

test_that("safe_logical returns default for NULL and NA", {
  expect_false(safe_logical(NULL))
  expect_false(safe_logical(NA))
  expect_true(safe_logical(NULL, default = TRUE))
  expect_true(safe_logical(NA, default = TRUE))
})

test_that("safe_logical returns default for unrecognized values", {
  expect_false(safe_logical("maybe"))
  expect_false(safe_logical("2"))
  expect_false(safe_logical(""))
  expect_true(safe_logical("maybe", default = TRUE))
  expect_true(safe_logical("unknown", default = TRUE))
})

test_that("safe_logical handles whitespace around values", {
  expect_true(safe_logical("  Y  "))
  expect_true(safe_logical(" YES "))
  expect_false(safe_logical("  N  "))
  expect_false(safe_logical(" NO "))
})

test_that("safe_logical handles numeric 1 and 0 as character strings", {
  expect_true(safe_logical("1"))
  expect_false(safe_logical("0"))
})

context("safe_numeric")

test_that("safe_numeric converts valid numeric strings", {
  expect_equal(safe_numeric("42"), 42)
  expect_equal(safe_numeric("3.14"), 3.14)
  expect_equal(safe_numeric("-10"), -10)
  expect_equal(safe_numeric("0"), 0)
  expect_equal(safe_numeric("1e3"), 1000)
})

test_that("safe_numeric passes through numeric values", {
  expect_equal(safe_numeric(42), 42)
  expect_equal(safe_numeric(3.14), 3.14)
  expect_equal(safe_numeric(-5), -5)
})

test_that("safe_numeric returns default for NULL and NA", {
  expect_true(is.na(safe_numeric(NULL)))
  expect_true(is.na(safe_numeric(NA)))
  expect_equal(safe_numeric(NULL, default = 0), 0)
  expect_equal(safe_numeric(NA, default = 99), 99)
})

test_that("safe_numeric returns default for non-numeric strings", {
  expect_true(is.na(safe_numeric("abc")))
  expect_true(is.na(safe_numeric("not a number")))
  expect_equal(safe_numeric("abc", default = 0), 0)
  expect_equal(safe_numeric("xyz", default = -1), -1)
})

test_that("safe_numeric handles empty string", {
  expect_true(is.na(safe_numeric("")))
  expect_equal(safe_numeric("", default = 0), 0)
})

test_that("safe_numeric does not produce warnings", {
  # as.numeric("abc") normally warns; safe_numeric should suppress this
  expect_silent(safe_numeric("abc"))
  expect_silent(safe_numeric("not_a_number"))
})


# ==============================================================================
# 6. CONFIG VALUE RETRIEVAL
# ==============================================================================

context("get_config_value")

test_that("get_config_value retrieves existing values", {
  config <- list(
    project_title = "My Survey",
    alpha = 0.05,
    apply_weighting = TRUE
  )

  expect_equal(get_config_value(config, "project_title"), "My Survey")
  expect_equal(get_config_value(config, "alpha"), 0.05)
  expect_true(get_config_value(config, "apply_weighting"))
})

test_that("get_config_value returns default for missing values", {
  config <- list(project_title = "Test")

  expect_null(get_config_value(config, "nonexistent"))
  expect_equal(get_config_value(config, "nonexistent", default_value = "fallback"), "fallback")
  expect_equal(get_config_value(config, "missing_num", default_value = 42), 42)
})

test_that("get_config_value returns default for NA values", {
  config <- list(setting1 = NA)

  expect_null(get_config_value(config, "setting1"))
  expect_equal(get_config_value(config, "setting1", default_value = "default"), "default")
})

test_that("get_config_value refuses when required setting is missing and no default", {
  config <- list(project_title = "Test")

  expect_error(
    get_config_value(config, "critical_setting", required = TRUE),
    class = "turas_refusal"
  )
})

test_that("get_config_value returns default_value for required setting when default provided", {
  config <- list(project_title = "Test")

  # When required=TRUE but a default_value is also provided, the default should be used
  result <- get_config_value(config, "missing_but_defaulted",
                             default_value = "safe_default",
                             required = TRUE)
  expect_equal(result, "safe_default")
})

test_that("get_config_value handles empty config list", {
  config <- list()

  expect_null(get_config_value(config, "anything"))
  expect_equal(get_config_value(config, "anything", default_value = "x"), "x")
})

test_that("get_config_value with required=FALSE does not error on missing", {
  config <- list()

  expect_null(get_config_value(config, "missing_setting", required = FALSE))
})

test_that("get_config_value returns actual value even when default is provided", {
  config <- list(alpha = 0.01)

  # Actual value should take precedence over default
  expect_equal(get_config_value(config, "alpha", default_value = 0.05), 0.01)
})


# ==============================================================================
# 7. TABS-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

context("Tabs Refusal Wrapper")

test_that("tabs_refuse throws a turas_refusal condition", {
  expect_error(
    tabs_refuse(
      code = "CFG_TEST_ERROR",
      title = "Test Error",
      problem = "This is a test",
      why_it_matters = "Testing matters",
      how_to_fix = "Fix it"
    ),
    class = "turas_refusal"
  )
})

test_that("tabs_refuse auto-prefixes codes without valid TRS prefix", {
  err <- tryCatch(
    tabs_refuse(
      code = "SOME_ERROR",
      title = "Test",
      problem = "Test problem",
      why_it_matters = "Testing",
      how_to_fix = "Fix"
    ),
    turas_refusal = function(e) e
  )

  # Should have been prefixed with CFG_
  expect_equal(err$code, "CFG_SOME_ERROR")
})

test_that("tabs_refuse preserves codes that already have valid prefix", {
  err <- tryCatch(
    tabs_refuse(
      code = "DATA_MISSING_COLUMN",
      title = "Test",
      problem = "Test problem",
      why_it_matters = "Testing",
      how_to_fix = "Fix"
    ),
    turas_refusal = function(e) e
  )

  expect_equal(err$code, "DATA_MISSING_COLUMN")
})

test_that("tabs_refuse preserves IO_ prefix", {
  err <- tryCatch(
    tabs_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "Test",
      problem = "Test problem",
      why_it_matters = "Testing",
      how_to_fix = "Fix"
    ),
    turas_refusal = function(e) e
  )

  expect_equal(err$code, "IO_FILE_NOT_FOUND")
})


# ==============================================================================
# 8. TRS STATUS HELPERS
# ==============================================================================

context("TRS Status Helpers")

test_that("tabs_status_pass creates PASS status object", {
  status <- tabs_status_pass()

  expect_s3_class(status, "trs_status")
  expect_equal(status$run_status, "PASS")
  expect_equal(status$module, "TABS")
})

test_that("tabs_status_pass includes results_count in details", {
  status <- tabs_status_pass(results_count = 42)

  expect_equal(status$details$questions_processed, 42)
})

test_that("tabs_status_partial creates PARTIAL status object", {
  status <- tabs_status_partial(
    degraded_reasons = c("High skip rate"),
    affected_outputs = c("question_coverage")
  )

  expect_s3_class(status, "trs_status")
  expect_equal(status$run_status, "PARTIAL")
  expect_equal(status$module, "TABS")
  expect_equal(status$degraded_reasons, "High skip rate")
  expect_equal(status$affected_outputs, "question_coverage")
})

test_that("tabs_status_partial includes skipped_questions in details", {
  status <- tabs_status_partial(
    degraded_reasons = c("Skipped"),
    affected_outputs = c("coverage"),
    skipped_questions = c("Q1", "Q5")
  )

  expect_equal(status$details$skipped_questions, c("Q1", "Q5"))
})

test_that("tabs_status_refuse creates REFUSE status object", {
  status <- tabs_status_refuse(
    code = "DATA_NO_RESPONDENTS",
    reason = "No respondents"
  )

  expect_equal(status$run_status, "REFUSE")
  expect_equal(status$module, "TABS")
})


# ==============================================================================
# 9. VALIDATION GATES
# ==============================================================================

context("Validation Gates")

test_that("validate_tabs_config refuses non-list config", {
  # Note: data.frame IS a list in R (is.list(data.frame()) == TRUE),

  # so it passes the is.list() check. Only truly non-list types are refused.
  expect_error(
    validate_tabs_config("not a list"),
    class = "turas_refusal"
  )
  expect_error(
    validate_tabs_config(42),
    class = "turas_refusal"
  )
  expect_error(
    validate_tabs_config(NULL),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_config accepts data.frame (which is also a list in R)", {
  # In R, data.frames inherit from list, so is.list() returns TRUE
  result <- validate_tabs_config(data.frame(a = 1))
  expect_true(result)
})

test_that("validate_tabs_config accepts valid list config", {
  result <- validate_tabs_config(list(alpha = 0.05))
  expect_true(result)
})

test_that("validate_tabs_data_file refuses when file does not exist", {
  expect_error(
    validate_tabs_data_file("/nonexistent/path/to/data.xlsx"),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_structure_file refuses when file does not exist", {
  expect_error(
    validate_tabs_structure_file("/nonexistent/Survey_Structure.xlsx"),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_survey_structure refuses non-list structure", {
  expect_error(
    validate_tabs_survey_structure("not a list"),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_survey_structure refuses empty questions", {
  structure <- list(
    questions = data.frame(
      QuestionCode = character(0),
      QuestionText = character(0),
      Variable_Type = character(0)
    ),
    options = data.frame()
  )

  expect_error(
    validate_tabs_survey_structure(structure),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_survey_structure refuses missing required columns", {
  structure <- list(
    questions = data.frame(
      QuestionCode = "Q1",
      SomeOtherCol = "test"
    ),
    options = data.frame()
  )

  expect_error(
    validate_tabs_survey_structure(structure),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_survey_structure accepts valid structure", {
  structure <- list(
    questions = data.frame(
      QuestionCode = "Q1",
      QuestionText = "How satisfied?",
      Variable_Type = "Single"
    ),
    options = data.frame()
  )

  result <- validate_tabs_survey_structure(structure)
  expect_true(result)
})

test_that("validate_tabs_selection refuses non-data.frame", {
  expect_error(
    validate_tabs_selection("not a data frame"),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_selection refuses missing QuestionCode column", {
  df <- data.frame(SomethingElse = "Q1", Include = "Y")

  expect_error(
    validate_tabs_selection(df),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_selection refuses missing Include column", {
  df <- data.frame(QuestionCode = "Q1")

  expect_error(
    validate_tabs_selection(df),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_selection refuses when no questions have Include=Y", {
  df <- data.frame(
    QuestionCode = c("Q1", "Q2"),
    Include = c("N", "N")
  )

  expect_error(
    validate_tabs_selection(df),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_selection accepts valid selection with included questions", {
  df <- data.frame(
    QuestionCode = c("Q1", "Q2", "Q3"),
    Include = c("Y", "N", "Y")
  )

  result <- validate_tabs_selection(df)
  expect_true(result)
})

test_that("validate_tabs_banner refuses NULL banner_info", {
  expect_error(
    validate_tabs_banner(NULL, data.frame()),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_banner refuses empty columns", {
  banner_info <- list(columns = list())

  expect_error(
    validate_tabs_banner(banner_info, data.frame()),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_banner refuses NULL columns", {
  banner_info <- list(columns = NULL)

  expect_error(
    validate_tabs_banner(banner_info, data.frame()),
    class = "turas_refusal"
  )
})

test_that("validate_tabs_banner accepts valid banner with columns", {
  banner_info <- list(
    columns = list(
      list(code = "Gender", label = "Gender"),
      list(code = "Age", label = "Age Group")
    )
  )

  result <- validate_tabs_banner(banner_info, data.frame())
  expect_true(result)
})

test_that("validate_question_column records skip when column missing from data", {
  guard <- tabs_guard_init()
  data <- data.frame(Q1 = 1:5, Q2 = 6:10)

  guard <- validate_question_column("Q99", data, guard)

  expect_equal(guard$skipped_questions, "Q99")
  expect_length(guard$warnings, 1)
})

test_that("validate_question_column does not record skip when column exists", {
  guard <- tabs_guard_init()
  data <- data.frame(Q1 = 1:5, Q2 = 6:10)

  guard <- validate_question_column("Q1", data, guard)

  expect_length(guard$skipped_questions, 0)
  expect_length(guard$warnings, 0)
})


# ==============================================================================
# 10. EDGE CASES AND INTEGRATION
# ==============================================================================

context("Edge Cases and Integration")

test_that("guard survives many recorded issues without error", {
  guard <- tabs_guard_init()

  for (i in 1:100) {
    guard <- guard_record_skipped_question(guard, paste0("Q", i), "stress test")
  }

  expect_length(guard$skipped_questions, 100)
  expect_length(guard$warnings, 100)

  summary <- tabs_guard_summary(guard)
  expect_true(summary$has_issues)
  expect_equal(summary$n_warnings, 100)
})

test_that("determine_status with large skip count returns PARTIAL", {
  guard <- tabs_guard_init()
  for (i in 1:50) {
    guard <- guard_record_skipped_question(guard, paste0("Q", i), "stress")
  }

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 50,
    n_questions_total = 100,
    n_respondents = 500,
    banner_columns = 12
  )

  expect_equal(status$run_status, "PARTIAL")
})

test_that("guard state is correctly immutable between calls", {
  guard1 <- tabs_guard_init()
  guard2 <- guard_record_skipped_question(guard1, "Q1", "test")

  # guard1 should be unmodified (R copy-on-modify semantics)
  # Note: In R, lists are copied on modification when assigned to a new name
  expect_length(guard1$skipped_questions, 0)
  expect_length(guard2$skipped_questions, 1)
})

test_that("empty base rate threshold of exactly 10% does not trigger PARTIAL", {
  guard <- tabs_guard_init()
  # 10 empty bases out of 100 total = exactly 10%
  for (i in 1:10) {
    guard <- guard_record_empty_base(guard, paste0("Q", i))
  }

  status <- tabs_determine_status(
    guard = guard,
    n_questions_processed = 100,
    n_questions_total = 100,
    n_respondents = 500,
    banner_columns = 12
  )

  # 10/100 = 10%, threshold is > 0.10, so exactly 10% does NOT trigger
  # the empty_base rate degradation (but the skipped_questions check from
  # the guard summary may still cause PARTIAL since empty_base_questions
  # are tracked separately)
  # Actually empty_base_questions trigger has_issues but empty base rate check
  # requires > 0.10 (strictly greater), so 10% should NOT trigger the
  # "High empty base rate" reason. However the presence of any empty_base_questions
  # does not separately create a degraded_reason - only the rate check does.
  # But wait - the guard HAS 10 warnings from empty bases, which means
  # summary$has_issues is TRUE. But that alone doesn't create a degraded_reason.
  # The 10 guard warnings don't directly trigger PARTIAL in determine_status.
  # Actually let me re-read the code...
  # The only empty_base check in determine_status is the rate > 0.10 check.
  # But the skipped_questions check in guard summary will NOT fire because
  # these are empty_base_questions, not skipped_questions.
  # So at exactly 10%, the empty_base rate should NOT trigger,
  # and skipped_questions is empty, banner_issues is empty, option_mapping_issues
  # is empty, stability is stable. But guard has warnings, so summary$has_issues
  # is TRUE. However has_issues alone does not create a PARTIAL status -
  # only specific checks in determine_status create degraded_reasons.
  # So this should be PASS!
  expect_equal(status$run_status, "PASS")
})

test_that("safe_logical with numeric TRUE/FALSE works", {
  expect_true(safe_logical(TRUE))
  expect_false(safe_logical(FALSE))
})

test_that("safe_numeric with already-numeric value returns it unchanged", {
  expect_equal(safe_numeric(3.14159), 3.14159)
  expect_equal(safe_numeric(0L), 0)
  expect_equal(safe_numeric(-Inf), -Inf)
})

test_that("resolve_path handles absolute paths on Unix", {
  result <- resolve_path("/base/dir", "/absolute/path/to/file.xlsx")
  # Should return the absolute path unchanged (normalized)
  expect_true(grepl("absolute/path/to/file.xlsx", result))
})

test_that("resolve_path combines base and relative paths", {
  result <- resolve_path("/base/project", "data/survey.csv")
  expect_true(grepl("base/project/data/survey.csv", result))
})

test_that("resolve_path strips ./ prefix from relative path", {
  result <- resolve_path("/base/project", "./data/survey.csv")
  expect_true(grepl("base/project/data/survey.csv", result))
})

test_that("resolve_path refuses empty base_path", {
  expect_error(
    resolve_path("", "data/survey.csv"),
    class = "turas_refusal"
  )
})

test_that("resolve_path refuses NULL relative_path", {
  expect_error(
    resolve_path("/base", NULL),
    class = "turas_refusal"
  )
})

test_that("resolve_path refuses empty relative_path", {
  expect_error(
    resolve_path("/base", ""),
    class = "turas_refusal"
  )
})
