# ==============================================================================
# TRACKER MODULE - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for generate_config_templates.R:
#   - generate_tracking_config_template()
#   - generate_question_mapping_template()
#   - generate_all_tracker_templates()
#
# Run with:
#   testthat::test_file("modules/tracker/tests/testthat/test_config_templates.R")
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
  candidate <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(candidate, "modules", "shared"))) {
      turas_root <- candidate
      tracker_root <- file.path(turas_root, "modules", "tracker")
      break
    }
    candidate <- dirname(candidate)
  }
}

# Source shared TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Source shared template infrastructure first (required by generator)
shared_styles <- file.path(turas_root, "modules", "shared", "template_styles.R")
if (file.exists(shared_styles)) source(shared_styles)

# Source the template generator
source(file.path(tracker_root, "lib", "generate_config_templates.R"))


# ==============================================================================
# TESTS: generate_tracking_config_template()
# ==============================================================================

test_that("generate_tracking_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_tracking_config_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_equal(result, tmp)
})

test_that("tracking config template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_tracking_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expected_sheets <- c("Settings", "Waves", "TrackedQuestions", "Banner")
  for (s in expected_sheets) {
    expect_true(s %in% sheets,
                info = sprintf("Missing sheet '%s'", s))
  }
})

test_that("Waves sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_tracking_config_template(tmp)
  waves <- openxlsx::read.xlsx(tmp, sheet = "Waves", startRow = 3)

  expected_cols <- c("WaveID", "WaveName", "DataFile")
  for (col in expected_cols) {
    expect_true(col %in% names(waves),
                info = sprintf("Missing column '%s' in Waves sheet", col))
  }
})

test_that("TrackedQuestions sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_tracking_config_template(tmp)
  tq <- openxlsx::read.xlsx(tmp, sheet = "TrackedQuestions", startRow = 3)

  expected_cols <- c("QuestionCode", "QuestionType", "TrackingSpecs")
  for (col in expected_cols) {
    expect_true(col %in% names(tq),
                info = sprintf("Missing column '%s' in TrackedQuestions sheet", col))
  }
})

test_that("Banner sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_tracking_config_template(tmp)
  banner <- openxlsx::read.xlsx(tmp, sheet = "Banner", startRow = 3)

  expected_cols <- c("BreakVariable", "BreakLabel")
  for (col in expected_cols) {
    expect_true(col %in% names(banner),
                info = sprintf("Missing column '%s' in Banner sheet", col))
  }
})


# ==============================================================================
# TESTS: generate_question_mapping_template()
# ==============================================================================

test_that("generate_question_mapping_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_question_mapping_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_equal(result, tmp)
})

test_that("question mapping template contains QuestionMap sheet", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_question_mapping_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("QuestionMap" %in% sheets)
})

test_that("QuestionMap sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_question_mapping_template(tmp)
  qm <- openxlsx::read.xlsx(tmp, sheet = "QuestionMap", startRow = 3)

  expected_cols <- c("QuestionCode", "QuestionType", "W1", "W2")
  for (col in expected_cols) {
    expect_true(col %in% names(qm),
                info = sprintf("Missing column '%s' in QuestionMap sheet", col))
  }
})


# ==============================================================================
# TESTS: generate_all_tracker_templates()
# ==============================================================================

test_that("generate_all_tracker_templates creates both files", {
  tmp_dir <- tempdir()
  out_dir <- file.path(tmp_dir, paste0("tracker_tpl_", Sys.getpid()))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  result <- generate_all_tracker_templates(out_dir)

  config_path <- file.path(out_dir, "Tracking_Config.xlsx")
  mapping_path <- file.path(out_dir, "Question_Mapping.xlsx")

  expect_true(file.exists(config_path),
              info = "Tracking_Config.xlsx should be created")
  expect_true(file.exists(mapping_path),
              info = "Question_Mapping.xlsx should be created")
  expect_true(is.list(result))
  expect_equal(result$config, config_path)
  expect_equal(result$mapping, mapping_path)
})
