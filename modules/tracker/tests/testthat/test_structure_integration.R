# ==============================================================================
# TEST SUITE: Survey Structure Integration & Custom Labels
# ==============================================================================
# Tests for:
#   - parse_spec_label() (=Label syntax)
#   - resolve_question_values() (text → numeric mapping)
#   - get_box_options() (BoxCategory lookup)
#   - load_wave_structure() / load_wave_config()
#   - normalize_metric_name() with box: prefix
#   - generate_metric_label() with custom labels
# ==============================================================================

library(testthat)

context("Survey Structure Integration")

# ==============================================================================
# SETUP: Source required modules
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source dependencies
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "question_mapper.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))

# Source shared weights utils
shared_lib <- file.path(turas_root, "modules", "shared", "lib")
source(file.path(shared_lib, "weights_utils.R"))

source(file.path(tracker_root, "lib", "wave_loader.R"))
source(file.path(tracker_root, "lib", "tracking_crosstab_engine.R"))

# ==============================================================================
# HELPERS
# ==============================================================================

create_mock_structure <- function() {
  data.frame(
    QuestionCode = c("Q1", "Q1", "Q1", "Q1", "Q1",
                     "Q2", "Q2", "Q2"),
    OptionText = c("Strongly Agree", "Somewhat Agree", "Neutral",
                   "Somewhat Disagree", "Strongly Disagree",
                   "Yes", "No", "Maybe"),
    DisplayText = c("Strongly Agree", "Somewhat Agree", "Neutral",
                    "Somewhat Disagree", "Strongly Disagree",
                    "Yes", "No", "Maybe"),
    Index_Weight = c(5, 4, 3, 2, 1, 1, 0, NA),
    BoxCategory = c("Agree", "Agree", "Neutral", "Disagree", "Disagree",
                    NA, NA, NA),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# TESTS: parse_spec_label()
# ==============================================================================

test_that("parse_spec_label handles spec without label", {
  result <- parse_spec_label("mean")
  expect_equal(result$core, "mean")
  expect_null(result$label)
})

test_that("parse_spec_label handles spec with label", {
  result <- parse_spec_label("mean=Average")
  expect_equal(result$core, "mean")
  expect_equal(result$label, "Average")
})

test_that("parse_spec_label handles range spec with label", {
  result <- parse_spec_label("range:4-5=Agree")
  expect_equal(result$core, "range:4-5")
  expect_equal(result$label, "Agree")
})

test_that("parse_spec_label handles box spec with label", {
  result <- parse_spec_label("box:Agree=Top Box")
  expect_equal(result$core, "box:Agree")
  expect_equal(result$label, "Top Box")
})

test_that("parse_spec_label handles category spec with label", {
  result <- parse_spec_label("category:Yes=Aware")
  expect_equal(result$core, "category:Yes")
  expect_equal(result$label, "Aware")
})

test_that("parse_spec_label handles empty label after =", {
  result <- parse_spec_label("mean=")
  expect_equal(result$core, "mean")
  expect_null(result$label)
})

test_that("parse_spec_label handles spec with spaces", {
  result <- parse_spec_label("  range:1-3 = Disagree  ")
  expect_equal(result$core, "range:1-3")
  expect_equal(result$label, "Disagree")
})

test_that("parse_spec_label handles label with multiple words", {
  result <- parse_spec_label("top2_box=Top 2 Box Score")
  expect_equal(result$core, "top2_box")
  expect_equal(result$label, "Top 2 Box Score")
})

test_that("parse_spec_label splits on first = only", {
  result <- parse_spec_label("range:4-5=Score=4 or 5")
  expect_equal(result$core, "range:4-5")
  expect_equal(result$label, "Score=4 or 5")
})


# ==============================================================================
# TESTS: resolve_question_values()
# ==============================================================================

test_that("resolve_question_values passes through numeric data", {
  values <- c(5, 4, 3, 2, 1)
  structure <- create_mock_structure()
  result <- resolve_question_values(values, structure, "Q1")
  expect_equal(result, values)
})

test_that("resolve_question_values passes through when no structure", {
  values <- c("Strongly Agree", "Neutral", "Disagree")
  result <- resolve_question_values(values, NULL, "Q1")
  expect_equal(result, values)
})

test_that("resolve_question_values maps text to Index_Weight", {
  values <- c("Strongly Agree", "Somewhat Agree", "Neutral",
              "Somewhat Disagree", "Strongly Disagree")
  structure <- create_mock_structure()
  result <- resolve_question_values(values, structure, "Q1")
  expect_equal(result, c(5, 4, 3, 2, 1))
})

test_that("resolve_question_values handles case insensitivity", {
  values <- c("strongly agree", "NEUTRAL", "Strongly Disagree")
  structure <- create_mock_structure()
  result <- resolve_question_values(values, structure, "Q1")
  expect_equal(result, c(5, 3, 1))
})

test_that("resolve_question_values handles NA in input", {
  values <- c("Strongly Agree", NA, "Neutral")
  structure <- create_mock_structure()
  result <- resolve_question_values(values, structure, "Q1")
  expect_equal(result[1], 5)
  expect_true(is.na(result[2]))
  expect_equal(result[3], 3)
})

test_that("resolve_question_values returns NA for unknown question", {
  values <- c("Yes", "No")
  structure <- create_mock_structure()
  # Q99 not in structure — tries numeric conversion
  expect_warning(
    result <- resolve_question_values(values, structure, "Q99"),
    "no structure mapping"
  )
  expect_true(all(is.na(result)))
})

test_that("resolve_question_values handles empty structure for question", {
  values <- c("Option A", "Option B")
  structure <- create_mock_structure()
  expect_warning(
    result <- resolve_question_values(values, structure, "Q99"),
    "no structure mapping"
  )
})


# ==============================================================================
# TESTS: get_box_options()
# ==============================================================================

test_that("get_box_options returns correct values for Agree", {
  structure <- create_mock_structure()
  result <- get_box_options(structure, "Q1", "Agree")
  expect_equal(sort(result), c(4, 5))
})

test_that("get_box_options returns correct values for Disagree", {
  structure <- create_mock_structure()
  result <- get_box_options(structure, "Q1", "Disagree")
  expect_equal(sort(result), c(1, 2))
})

test_that("get_box_options returns correct values for Neutral", {
  structure <- create_mock_structure()
  result <- get_box_options(structure, "Q1", "Neutral")
  expect_equal(result, 3)
})

test_that("get_box_options is case insensitive", {
  structure <- create_mock_structure()
  result <- get_box_options(structure, "Q1", "agree")
  expect_equal(sort(result), c(4, 5))
})

test_that("get_box_options warns for unknown category", {
  structure <- create_mock_structure()
  expect_warning(
    result <- get_box_options(structure, "Q1", "Unknown"),
    "not found"
  )
  expect_null(result)
})

test_that("get_box_options warns for question with no BoxCategory", {
  structure <- create_mock_structure()
  expect_warning(
    result <- get_box_options(structure, "Q2", "Agree"),
    "empty"
  )
  expect_null(result)
})

test_that("get_box_options refuses when no structure provided", {
  expect_error(
    get_box_options(NULL, "Q1", "Agree"),
    "REFUSED|StructureFile"
  )
})


# ==============================================================================
# TESTS: normalize_metric_name() with box:
# ==============================================================================

test_that("normalize_metric_name handles box: spec", {
  expect_equal(normalize_metric_name("box:agree"), "box_agree")
  expect_equal(normalize_metric_name("box:strongly agree"), "box_strongly_agree")
})

test_that("normalize_metric_name handles range: spec", {
  expect_equal(normalize_metric_name("range:4-5"), "range_4_5")
})

test_that("normalize_metric_name handles simple specs", {
  expect_equal(normalize_metric_name("mean"), "mean")
  expect_equal(normalize_metric_name("top2_box"), "top2_box")
})


# ==============================================================================
# TESTS: generate_metric_label() with custom labels
# ==============================================================================

test_that("generate_metric_label uses custom label from =Label", {
  result <- generate_metric_label(
    spec = "range:4-5",
    metric_label_override = NA,
    question_text = "Overall satisfaction",
    metric_type = "rating_enhanced",
    specs_list = c("mean", "range:4-5"),
    custom_label = "Agree"
  )
  expect_true(grepl("\\(Agree\\)", result))
})

test_that("generate_metric_label uses default for box: without custom label", {
  result <- generate_metric_label(
    spec = "box:Agree",
    metric_label_override = NA,
    question_text = "Satisfaction",
    metric_type = "rating_enhanced",
    specs_list = c("mean", "box:Agree"),
    custom_label = NULL
  )
  expect_true(grepl("\\(% Agree\\)", result))
})

test_that("generate_metric_label default for mean without custom label", {
  result <- generate_metric_label(
    spec = "mean",
    metric_label_override = NA,
    question_text = "Satisfaction",
    metric_type = "rating_enhanced",
    specs_list = c("mean"),
    custom_label = NULL
  )
  expect_true(grepl("\\(Mean\\)", result))
})

test_that("generate_metric_label custom label overrides default", {
  result <- generate_metric_label(
    spec = "mean",
    metric_label_override = NA,
    question_text = "Satisfaction",
    metric_type = "rating_enhanced",
    specs_list = c("mean", "top2_box"),
    custom_label = "Average Score"
  )
  expect_true(grepl("\\(Average Score\\)", result))
})

test_that("generate_metric_label MetricLabel override still works", {
  result <- generate_metric_label(
    spec = "mean",
    metric_label_override = "Custom Override",
    question_text = "Satisfaction",
    metric_type = "rating_enhanced",
    specs_list = c("mean"),
    custom_label = NULL
  )
  expect_equal(result, "Custom Override")
})


# ==============================================================================
# TESTS: validate_tracking_specs() with =Label and box:
# ==============================================================================

test_that("validate_tracking_specs accepts specs with labels", {
  expect_silent(
    validate_tracking_specs("mean=Average,top2_box=Agree", "Rating")
  )
})

test_that("validate_tracking_specs accepts box: for rating type", {
  expect_silent(
    validate_tracking_specs("mean,box:Agree,box:Disagree", "Rating")
  )
})

test_that("validate_tracking_specs accepts box: with label", {
  expect_silent(
    validate_tracking_specs("box:Agree=Top Box,box:Disagree=Bottom Box", "Likert")
  )
})

test_that("validate_tracking_specs accepts range with label", {
  expect_silent(
    validate_tracking_specs("range:4-5=Agree,range:1-2=Disagree", "Rating")
  )
})

test_that("validate_tracking_specs accepts category with label", {
  expect_silent(
    validate_tracking_specs("category:Yes=Aware", "Single_Response")
  )
})

test_that("validate_tracking_specs accepts composite with box: spec", {
  expect_silent(
    validate_tracking_specs("mean,box:Agree", "Composite")
  )
})


# ==============================================================================
# TESTS: load_wave_structure() / load_wave_config()
# ==============================================================================

test_that("load_wave_structure reads Options sheet correctly", {
  skip_if_not_installed("openxlsx")

  # Create temporary structure file
  tmp_file <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Options")

  options_df <- data.frame(
    QuestionCode = c("Q1", "Q1", "Q1"),
    OptionText = c("Yes", "No", "Maybe"),
    DisplayText = c("Yes", "No", "Maybe"),
    Index_Weight = c(1, 0, NA),
    BoxCategory = c("Positive", "Negative", NA),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Options", options_df)
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)

  result <- load_wave_structure(tmp_file, "W1")
  expect_equal(nrow(result), 3)
  expect_equal(result$QuestionCode, c("Q1", "Q1", "Q1"))
  expect_equal(result$Index_Weight, c(1, 0, NA))
  expect_equal(result$BoxCategory, c("Positive", "Negative", NA))

  unlink(tmp_file)
})

test_that("load_wave_structure handles missing optional columns", {
  skip_if_not_installed("openxlsx")

  tmp_file <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Options")

  # Only required columns
  options_df <- data.frame(
    QuestionCode = c("Q1", "Q1"),
    OptionText = c("Yes", "No"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Options", options_df)
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)

  result <- load_wave_structure(tmp_file, "W1")
  expect_equal(nrow(result), 2)
  expect_true("DisplayText" %in% names(result))
  expect_true("Index_Weight" %in% names(result))
  expect_true("BoxCategory" %in% names(result))
  # DisplayText defaults to OptionText
  expect_equal(result$DisplayText, c("Yes", "No"))

  unlink(tmp_file)
})

test_that("load_wave_config reads weighting settings", {
  skip_if_not_installed("openxlsx")

  tmp_file <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")

  settings_df <- data.frame(
    Setting = c("apply_weighting", "weight_variable", "alpha"),
    Value = c("TRUE", "weight_col", "0.05"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", settings_df)
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)

  result <- load_wave_config(tmp_file, "W1")
  expect_true(result$apply_weighting)
  expect_equal(result$weight_variable, "weight_col")

  unlink(tmp_file)
})

test_that("load_wave_config handles missing weighting settings", {
  skip_if_not_installed("openxlsx")

  tmp_file <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")

  settings_df <- data.frame(
    Setting = c("alpha", "output_filename"),
    Value = c("0.05", "report.xlsx"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", settings_df)
  openxlsx::saveWorkbook(wb, tmp_file, overwrite = TRUE)

  result <- load_wave_config(tmp_file, "W1")
  expect_false(result$apply_weighting)
  expect_null(result$weight_variable)

  unlink(tmp_file)
})


# ==============================================================================
# TESTS: resolve_support_file_path()
# ==============================================================================

test_that("resolve_support_file_path returns NULL for empty input", {
  expect_null(resolve_support_file_path(NULL))
  expect_null(resolve_support_file_path(NA))
  expect_null(resolve_support_file_path(""))
  expect_null(resolve_support_file_path("  "))
})

test_that("resolve_support_file_path resolves existing absolute path", {
  tmp_file <- tempfile(fileext = ".xlsx")
  writeLines("test", tmp_file)

  result <- resolve_support_file_path(tmp_file)
  expect_equal(result, normalizePath(tmp_file))

  unlink(tmp_file)
})

test_that("resolve_support_file_path resolves relative to data_dir", {
  tmp_dir <- tempdir()
  tmp_file <- file.path(tmp_dir, "structure.xlsx")
  writeLines("test", tmp_file)

  result <- resolve_support_file_path("structure.xlsx", data_dir = tmp_dir)
  expect_equal(result, normalizePath(tmp_file))

  unlink(tmp_file)
})
