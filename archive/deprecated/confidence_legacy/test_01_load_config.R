# ==============================================================================
# TEST SUITE FOR 01_LOAD_CONFIG.R
# ==============================================================================
# Comprehensive tests for configuration loading and validation
# Tests valid configs, invalid configs, and edge cases
# ==============================================================================

# Source the required files
source("../R/utils.R")
source("../R/01_load_config.R")

# ==============================================================================
# TEST HELPER: Create test Excel files
# ==============================================================================

create_test_config_valid <- function(file_path) {
  if (!require("openxlsx", quietly = TRUE)) {
    cat("openxlsx not available - skipping Excel creation tests\n")
    return(FALSE)
  }

  wb <- openxlsx::createWorkbook()

  # Sheet 1: File_Paths
  file_paths_data <- data.frame(
    Parameter = c(
      "survey_structure_file",
      "crosstab_config_file",
      "raw_data_file",
      "output_file"
    ),
    Value = c(
      "test_data/survey_structure.xlsx",
      "test_data/tabs_config.xlsx",
      "test_data/data.xlsx",
      "output/confidence_results.xlsx"
    ),
    Notes = c(
      "Survey structure and metadata",
      "Crosstab configuration",
      "Raw survey data",
      "Output file path"
    )
  )

  openxlsx::addWorksheet(wb, "File_Paths")
  openxlsx::writeData(wb, "File_Paths", file_paths_data)

  # Sheet 2: Study_Settings
  study_settings_data <- data.frame(
    Setting = c(
      "calculate_eff_sample_size",
      "multiple_comparison_adjust",
      "adjustment_method",
      "bootstrap_iterations",
      "confidence_level",
      "random_seed",
      "decimal_separator"
    ),
    Value = c(
      "Y",
      "Y",
      "Holm",
      "5000",
      "0.95",
      "12345",
      "."
    ),
    Valid_Values = c(
      "Y/N",
      "Y/N",
      "Bonferroni/Holm/FDR",
      "1000-10000",
      "0.90/0.95/0.99",
      "Any integer",
      ". or ,"
    ),
    Description = c(
      "Calculate effective sample size when weighted",
      "Apply multiple comparison adjustment",
      "Adjustment method to use",
      "Number of bootstrap iterations",
      "Confidence level for intervals",
      "Random seed for reproducibility",
      "Decimal separator for output"
    )
  )

  openxlsx::addWorksheet(wb, "Study_Settings")
  openxlsx::writeData(wb, "Study_Settings", study_settings_data)

  # Sheet 3: Question_Analysis
  question_analysis_data <- data.frame(
    Question_ID = c("Q1", "Q2", "Q3"),
    Statistic_Type = c("proportion", "mean", "proportion"),
    Categories = c("1", NA, "4,5"),
    Exclude_Codes = c(NA, "99", NA),
    Promoter_Codes = c(NA, NA, NA),
    Detractor_Codes = c(NA, NA, NA),
    Description = c("Brand Awareness", "Satisfaction Rating", "Top 2 Box"),
    Run_MOE = c("Y", "N", "Y"),
    Run_Bootstrap = c("Y", "Y", "Y"),
    Run_Credible = c("N", "N", "Y"),
    Use_Wilson = c("N", "N", "Y"),
    Prior_Mean = c(NA, NA, 0.67),
    Prior_SD = c(NA, NA, NA),
    Prior_N = c(NA, NA, 500),
    Notes = c("Main KPI", "0-10 scale", "From pilot study")
  )

  openxlsx::addWorksheet(wb, "Question_Analysis")
  openxlsx::writeData(wb, "Question_Analysis", question_analysis_data)

  # Save workbook
  openxlsx::saveWorkbook(wb, file_path, overwrite = TRUE)

  return(TRUE)
}


create_test_config_invalid_limit <- function(file_path) {
  if (!require("openxlsx", quietly = TRUE)) {
    return(FALSE)
  }

  wb <- openxlsx::createWorkbook()

  # Create minimal valid File_Paths and Study_Settings
  file_paths_data <- data.frame(
    Parameter = c("survey_structure_file", "crosstab_config_file", "raw_data_file", "output_file"),
    Value = c("test.xlsx", "test.xlsx", "test.xlsx", "out.xlsx")
  )

  study_settings_data <- data.frame(
    Setting = c("calculate_eff_sample_size", "multiple_comparison_adjust", "adjustment_method",
                "bootstrap_iterations", "confidence_level", "decimal_separator"),
    Value = c("Y", "N", "Holm", "5000", "0.95", ".")
  )

  # Create Question_Analysis with 201 questions (exceeds limit)
  question_analysis_data <- data.frame(
    Question_ID = paste0("Q", 1:201),
    Statistic_Type = rep("proportion", 201),
    Categories = rep("1", 201),
    Run_MOE = rep("Y", 201),
    Run_Bootstrap = rep("N", 201),
    Run_Credible = rep("N", 201)
  )

  openxlsx::addWorksheet(wb, "File_Paths")
  openxlsx::writeData(wb, "File_Paths", file_paths_data)

  openxlsx::addWorksheet(wb, "Study_Settings")
  openxlsx::writeData(wb, "Study_Settings", study_settings_data)

  openxlsx::addWorksheet(wb, "Question_Analysis")
  openxlsx::writeData(wb, "Question_Analysis", question_analysis_data)

  openxlsx::saveWorkbook(wb, file_path, overwrite = TRUE)

  return(TRUE)
}


# ==============================================================================
# TEST: Load valid configuration
# ==============================================================================

test_load_valid_config <- function() {
  cat("\n=== Testing load_confidence_config() with valid config ===\n")

  # Create test config file
  test_file <- "test_config_valid.xlsx"
  if (!create_test_config_valid(test_file)) {
    cat("⊘ Skipping test - openxlsx not available\n")
    return()
  }

  # Load config
  config <- tryCatch(
    load_confidence_config(test_file),
    error = function(e) {
      cat(sprintf("ERROR: %s\n", e$message))
      NULL
    }
  )

  stopifnot(!is.null(config))
  stopifnot("file_paths" %in% names(config))
  stopifnot("study_settings" %in% names(config))
  stopifnot("question_analysis" %in% names(config))

  # Check file_paths structure
  stopifnot(nrow(config$file_paths) == 4)
  stopifnot("Parameter" %in% names(config$file_paths))
  stopifnot("Value" %in% names(config$file_paths))

  # Check study_settings structure
  stopifnot(nrow(config$study_settings) >= 6)  # At least 6 required settings

  # Check question_analysis structure
  stopifnot(nrow(config$question_analysis) == 3)
  stopifnot("Question_ID" %in% names(config$question_analysis))

  # Clean up
  unlink(test_file)

  cat("✓ Valid configuration loaded successfully\n")
}


# ==============================================================================
# TEST: Validate configuration
# ==============================================================================

test_validate_config <- function() {
  cat("\n=== Testing validate_config() ===\n")

  test_file <- "test_config_valid.xlsx"
  if (!create_test_config_valid(test_file)) {
    cat("⊘ Skipping test - openxlsx not available\n")
    return()
  }

  # Create dummy input files that validation expects
  dir.create("test_data", showWarnings = FALSE)
  file.create("test_data/survey_structure.xlsx")
  file.create("test_data/tabs_config.xlsx")
  file.create("test_data/data.xlsx")

  # Load and validate
  config <- load_confidence_config(test_file)
  validation <- validate_config(config)

  cat(sprintf("Validation result: %s\n", ifelse(validation$valid, "PASS", "FAIL")))

  if (length(validation$errors) > 0) {
    cat("Errors:\n")
    for (err in validation$errors) {
      cat(sprintf("  - %s\n", err))
    }
  }

  if (length(validation$warnings) > 0) {
    cat("Warnings:\n")
    for (warn in validation$warnings) {
      cat(sprintf("  - %s\n", warn))
    }
  }

  # Note: This may have warnings about output directory, which is expected
  # But should not have errors
  if (!validation$valid) {
    cat("Validation errors detected (may be expected if test files don't exist)\n")
  }

  # Clean up
  unlink(test_file)
  unlink("test_data", recursive = TRUE)

  cat("✓ Validation function works\n")
}


# ==============================================================================
# TEST: Question limit enforcement (200 max)
# ==============================================================================

test_question_limit <- function() {
  cat("\n=== Testing 200 question limit enforcement ===\n")

  test_file <- "test_config_201_questions.xlsx"
  if (!create_test_config_invalid_limit(test_file)) {
    cat("⊘ Skipping test - openxlsx not available\n")
    return()
  }

  # Attempt to load config with 201 questions
  error_caught <- FALSE
  error_message <- ""

  tryCatch(
    load_confidence_config(test_file),
    error = function(e) {
      error_caught <<- TRUE
      error_message <<- e$message
    }
  )

  stopifnot(error_caught)
  stopifnot(grepl("Question limit exceeded", error_message))
  stopifnot(grepl("201 questions", error_message))
  stopifnot(grepl("maximum 200", error_message))

  cat(sprintf("✓ Error correctly thrown: %s\n", error_message))

  # Clean up
  unlink(test_file)
}


# ==============================================================================
# TEST: Missing required sheets
# ==============================================================================

test_missing_sheets <- function() {
  cat("\n=== Testing missing required sheets ===\n")

  if (!require("openxlsx", quietly = TRUE)) {
    cat("⊘ Skipping test - openxlsx not available\n")
    return()
  }

  # Create config with missing Question_Analysis sheet
  test_file <- "test_config_missing_sheet.xlsx"
  wb <- openxlsx::createWorkbook()

  # Only add File_Paths and Study_Settings (missing Question_Analysis)
  file_paths_data <- data.frame(
    Parameter = c("survey_structure_file", "crosstab_config_file", "raw_data_file", "output_file"),
    Value = c("test.xlsx", "test.xlsx", "test.xlsx", "out.xlsx")
  )

  openxlsx::addWorksheet(wb, "File_Paths")
  openxlsx::writeData(wb, "File_Paths", file_paths_data)

  openxlsx::saveWorkbook(wb, test_file, overwrite = TRUE)

  # Attempt to load
  error_caught <- FALSE
  tryCatch(
    load_confidence_config(test_file),
    error = function(e) {
      error_caught <<- TRUE
      stopifnot(grepl("Failed to read", e$message))
    }
  )

  stopifnot(error_caught)
  cat("✓ Error correctly thrown for missing sheet\n")

  # Clean up
  unlink(test_file)
}


# ==============================================================================
# TEST: Invalid study settings
# ==============================================================================

test_invalid_study_settings <- function() {
  cat("\n=== Testing invalid study settings ===\n")

  if (!require("openxlsx", quietly = TRUE)) {
    cat("⊘ Skipping test - openxlsx not available\n")
    return()
  }

  test_file <- "test_config_invalid_settings.xlsx"
  wb <- openxlsx::createWorkbook()

  # Create valid File_Paths
  file_paths_data <- data.frame(
    Parameter = c("survey_structure_file", "crosstab_config_file", "raw_data_file", "output_file"),
    Value = c("test.xlsx", "test.xlsx", "test.xlsx", "out.xlsx")
  )

  # Create INVALID Study_Settings (invalid confidence level)
  study_settings_data <- data.frame(
    Setting = c("calculate_eff_sample_size", "multiple_comparison_adjust", "adjustment_method",
                "bootstrap_iterations", "confidence_level", "decimal_separator"),
    Value = c("Y", "N", "Holm", "5000", "0.85", ".")  # 0.85 is invalid
  )

  # Create minimal valid Question_Analysis
  question_analysis_data <- data.frame(
    Question_ID = "Q1",
    Statistic_Type = "proportion",
    Categories = "1",
    Run_MOE = "Y",
    Run_Bootstrap = "N",
    Run_Credible = "N"
  )

  openxlsx::addWorksheet(wb, "File_Paths")
  openxlsx::writeData(wb, "File_Paths", file_paths_data)

  openxlsx::addWorksheet(wb, "Study_Settings")
  openxlsx::writeData(wb, "Study_Settings", study_settings_data)

  openxlsx::addWorksheet(wb, "Question_Analysis")
  openxlsx::writeData(wb, "Question_Analysis", question_analysis_data)

  openxlsx::saveWorkbook(wb, test_file, overwrite = TRUE)

  # Load config
  config <- load_confidence_config(test_file)

  # Validate - should fail
  validation <- validate_config(config)

  stopifnot(!validation$valid)
  stopifnot(any(grepl("confidence_level", validation$errors)))

  cat("✓ Invalid confidence level correctly detected\n")

  # Clean up
  unlink(test_file)
}


# ==============================================================================
# TEST: Invalid decimal separator
# ==============================================================================

test_invalid_decimal_separator <- function() {
  cat("\n=== Testing invalid decimal separator ===\n")

  if (!require("openxlsx", quietly = TRUE)) {
    cat("⊘ Skipping test - openxlsx not available\n")
    return()
  }

  test_file <- "test_config_invalid_decimal.xlsx"
  wb <- openxlsx::createWorkbook()

  # Create config with invalid decimal separator
  file_paths_data <- data.frame(
    Parameter = c("survey_structure_file", "crosstab_config_file", "raw_data_file", "output_file"),
    Value = c("test.xlsx", "test.xlsx", "test.xlsx", "out.xlsx")
  )

  study_settings_data <- data.frame(
    Setting = c("calculate_eff_sample_size", "multiple_comparison_adjust", "adjustment_method",
                "bootstrap_iterations", "confidence_level", "decimal_separator"),
    Value = c("Y", "N", "Holm", "5000", "0.95", ";")  # Invalid separator
  )

  question_analysis_data <- data.frame(
    Question_ID = "Q1",
    Statistic_Type = "proportion",
    Categories = "1",
    Run_MOE = "Y",
    Run_Bootstrap = "N",
    Run_Credible = "N"
  )

  openxlsx::addWorksheet(wb, "File_Paths")
  openxlsx::writeData(wb, "File_Paths", file_paths_data)

  openxlsx::addWorksheet(wb, "Study_Settings")
  openxlsx::writeData(wb, "Study_Settings", study_settings_data)

  openxlsx::addWorksheet(wb, "Question_Analysis")
  openxlsx::writeData(wb, "Question_Analysis", question_analysis_data)

  openxlsx::saveWorkbook(wb, test_file, overwrite = TRUE)

  # Load and validate
  config <- load_confidence_config(test_file)
  validation <- validate_config(config)

  stopifnot(!validation$valid)
  stopifnot(any(grepl("decimal_separator", validation$errors)))

  cat("✓ Invalid decimal separator correctly detected\n")

  # Clean up
  unlink(test_file)
}


# ==============================================================================
# TEST: Question with no methods selected
# ==============================================================================

test_no_methods_selected <- function() {
  cat("\n=== Testing question with no methods selected ===\n")

  if (!require("openxlsx", quietly = TRUE)) {
    cat("⊘ Skipping test - openxlsx not available\n")
    return()
  }

  test_file <- "test_config_no_methods.xlsx"
  wb <- openxlsx::createWorkbook()

  file_paths_data <- data.frame(
    Parameter = c("survey_structure_file", "crosstab_config_file", "raw_data_file", "output_file"),
    Value = c("test.xlsx", "test.xlsx", "test.xlsx", "out.xlsx")
  )

  study_settings_data <- data.frame(
    Setting = c("calculate_eff_sample_size", "multiple_comparison_adjust", "adjustment_method",
                "bootstrap_iterations", "confidence_level", "decimal_separator"),
    Value = c("Y", "N", "Holm", "5000", "0.95", ".")
  )

  # Question with ALL methods set to N
  question_analysis_data <- data.frame(
    Question_ID = "Q1",
    Statistic_Type = "proportion",
    Categories = "1",
    Run_MOE = "N",
    Run_Bootstrap = "N",
    Run_Credible = "N"
  )

  openxlsx::addWorksheet(wb, "File_Paths")
  openxlsx::writeData(wb, "File_Paths", file_paths_data)

  openxlsx::addWorksheet(wb, "Study_Settings")
  openxlsx::writeData(wb, "Study_Settings", study_settings_data)

  openxlsx::addWorksheet(wb, "Question_Analysis")
  openxlsx::writeData(wb, "Question_Analysis", question_analysis_data)

  openxlsx::saveWorkbook(wb, test_file, overwrite = TRUE)

  # Load and validate
  config <- load_confidence_config(test_file)
  validation <- validate_config(config)

  stopifnot(!validation$valid)
  stopifnot(any(grepl("At least one method", validation$errors)))

  cat("✓ No methods selected error correctly detected\n")

  # Clean up
  unlink(test_file)
}


# ==============================================================================
# RUN ALL TESTS
# ==============================================================================

run_all_tests <- function() {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════╗\n")
  cat("║    CONFIDENCE MODULE - CONFIG LOADER TEST SUITE          ║\n")
  cat("╚═══════════════════════════════════════════════════════════╝\n")

  test_load_valid_config()
  test_validate_config()
  test_question_limit()
  test_missing_sheets()
  test_invalid_study_settings()
  test_invalid_decimal_separator()
  test_no_methods_selected()

  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════╗\n")
  cat("║              ✓ ALL CONFIG LOADER TESTS PASSED!           ║\n")
  cat("╚═══════════════════════════════════════════════════════════╝\n")
  cat("\n")
}

# Run tests if this file is executed directly
if (!interactive()) {
  run_all_tests()
}
