# ==============================================================================
# OUTPUT GENERATOR - TURAS V10.1
# ==============================================================================
# Functions for generating Excel output with confidence analysis results
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Refactored for maintainability (2025-12-27)
#          - Split into focused sub-modules
#          - output_formatting.R: Excel formatting utilities
#          - output_detail.R: Detail sheets for proportions, means, NPS
#          - output_sheets.R: Summary, study level, and documentation sheets
# Turas v10.0 - Initial release (2025-11-13)
#          - Multi-sheet Excel workbook generation
#          - Decimal separator support (period or comma)
#          - Summary, detailed results, methodology, and warnings
#          - Professional formatting with openxlsx
#
# OUTPUT STRUCTURE:
# Sheet 1: Summary - High-level overview
# Sheet 2: Study_Level - DEFF and effective sample size
# Sheet 3: Representativeness_Weights - Weight diagnostics and margin comparison
# Sheet 4: Proportions_Detail - All proportion confidence intervals
# Sheet 5: Means_Detail - All mean confidence intervals
# Sheet 6: NPS_Detail - All NPS confidence intervals
# Sheet 7: Methodology - Statistical methods documentation
# Sheet 8: Warnings - Data quality and calculation warnings
# Sheet 9: Inputs - Configuration summary
# Sheet 10: Run_Status - TRS run status (if TRS enabled)
#
# DECIMAL SEPARATOR:
# - All numeric output formatted with user-specified separator (. or ,)
# - Applied at final output stage only
# - Internal calculations always use period
#
# DEPENDENCIES:
# - openxlsx (for Excel writing)
# - utils.R
# - output_formatting.R (formatting utilities)
# - output_detail.R (detail sheet generators)
# - output_sheets.R (summary and documentation sheet generators)
# ==============================================================================

OUTPUT_VERSION <- "10.1"


# ==============================================================================
# DEPENDENCIES
# ==============================================================================

if (!require("openxlsx", quietly = TRUE)) {
  confidence_refuse(
    code = "PKG_OPENXLSX_MISSING",
    title = "Required Package Not Installed",
    problem = "Package 'openxlsx' is required but not installed",
    why_it_matters = "The openxlsx package is required to write Excel output files.",
    how_to_fix = "Install the package with: install.packages('openxlsx')"
  )
}

source_if_exists <- function(file_path) {
  if (file.exists(file_path)) {
    source(file_path)
  } else if (file.exists(file.path("R", file_path))) {
    source(file.path("R", file_path))
  } else if (file.exists(file.path("..", "R", file_path))) {
    source(file.path("..", "R", file_path))
  }
}

# Source utilities
source_if_exists("utils.R")

# Source output sub-modules
source_if_exists("output_formatting.R")
source_if_exists("output_detail.R")
source_if_exists("output_sheets.R")


# ==============================================================================
# MAIN OUTPUT FUNCTION
# ==============================================================================

#' Generate confidence analysis Excel output
#'
#' Creates comprehensive Excel workbook with all confidence analysis results.
#' Includes multiple sheets for summary, detailed results, methodology, and warnings.
#'
#' @param output_path Character. Path for output Excel file
#' @param study_level_stats Data frame. Study-level statistics (DEFF, effective n)
#' @param proportion_results List. Results from proportion analyses
#' @param mean_results List. Results from mean analyses
#' @param nps_results List. Results from NPS analyses
#' @param config List. Configuration settings
#' @param warnings Character vector. Any warnings generated during analysis
#' @param decimal_sep Character. Decimal separator ("." or ",")
#' @param run_result List. TRS run result object (optional)
#'
#' @return Logical. TRUE if successful (invisible)
#'
#' @examples
#' write_confidence_output(
#'   output_path = "output/confidence_results.xlsx",
#'   study_level_stats = study_stats,
#'   proportion_results = prop_results,
#'   mean_results = mean_results,
#'   nps_results = nps_results,
#'   config = config,
#'   warnings = warnings,
#'   decimal_sep = "."
#' )
#'
#' @author Confidence Module Team
#' @date 2025-12-27
#' @export
write_confidence_output <- function(output_path,
                                    study_level_stats = NULL,
                                    proportion_results = list(),
                                    mean_results = list(),
                                    nps_results = list(),
                                    config = list(),
                                    warnings = character(),
                                    decimal_sep = ".",
                                    run_result = NULL) {

  # Validate decimal separator
  if (!decimal_sep %in% c(".", ",")) {
    confidence_refuse(
      code = "CFG_INVALID_DECIMAL_SEPARATOR",
      title = "Invalid Decimal Separator",
      problem = "decimal_sep must be either '.' or ','",
      why_it_matters = "Decimal separator determines number formatting in output.",
      how_to_fix = "Set Decimal_Separator in config to either '.' or ','"
    )
  }

  # Validate output path before creating workbook
  output_dir <- dirname(output_path)

  # Check if output directory exists
  if (!dir.exists(output_dir)) {
    confidence_refuse(
      code = "IO_OUTPUT_DIR_NOT_FOUND",
      title = "Output Directory Does Not Exist",
      problem = sprintf("Output directory does not exist: %s", output_dir),
      why_it_matters = "Output files cannot be created without a valid directory.",
      how_to_fix = c(
        "Create the output directory first",
        "Or specify a different output path in the config"
      )
    )
  }

  # Check if output directory is writable
  if (file.access(output_dir, mode = 2) != 0) {
    confidence_refuse(
      code = "IO_OUTPUT_DIR_NOT_WRITABLE",
      title = "Output Directory Not Writable",
      problem = sprintf("Output directory is not writable: %s", output_dir),
      why_it_matters = "Write permissions are required to save output files.",
      how_to_fix = c(
        "Check directory permissions",
        "Ensure you have write access to the directory"
      )
    )
  }

  # Check if output file exists and is writable (if it exists)
  if (file.exists(output_path) && file.access(output_path, mode = 2) != 0) {
    confidence_refuse(
      code = "IO_OUTPUT_FILE_NOT_WRITABLE",
      title = "Cannot Overwrite Output File",
      problem = sprintf("Cannot overwrite existing output file: %s", output_path),
      why_it_matters = "File must be writable to save updated results.",
      how_to_fix = c(
        "Close the file if it's open in Excel",
        "Check file permissions",
        "Or specify a different filename in the config"
      )
    )
  }

  # Guard check: ensure we have some results to write
  has_results <- (!is.null(study_level_stats) && nrow(study_level_stats) > 0) ||
                 length(proportion_results) > 0 ||
                 length(mean_results) > 0 ||
                 length(nps_results) > 0

  if (!has_results) {
    warning("No analysis results to write. Output file will contain summary/methodology only.", call. = FALSE)
  }

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Sheet 1: Summary
  add_summary_sheet(wb, study_level_stats, proportion_results, mean_results,
                    nps_results, config, warnings, decimal_sep)

  # Sheet 2: Study Level
  if (!is.null(study_level_stats) && nrow(study_level_stats) > 0) {
    add_study_level_sheet(wb, study_level_stats, decimal_sep)
  }

  # Sheet 3: Representativeness & Weights (if available)
  if (!is.null(study_level_stats)) {
    add_representativeness_sheet(wb, study_level_stats, decimal_sep)
  }

  # Sheet 4: Proportions Detail
  if (length(proportion_results) > 0) {
    add_proportions_detail_sheet(wb, proportion_results, decimal_sep)
  }

  # Sheet 5: Means Detail
  if (length(mean_results) > 0) {
    add_means_detail_sheet(wb, mean_results, decimal_sep)
  }

  # Sheet 6: NPS Detail
  if (length(nps_results) > 0) {
    add_nps_detail_sheet(wb, nps_results, decimal_sep)
  }

  # Sheet 7: Methodology
  add_methodology_sheet(wb)

  # Sheet 8: Warnings
  add_warnings_sheet(wb, warnings)

  # Sheet 9: Inputs
  add_inputs_sheet(wb, config, decimal_sep)

  # Sheet 10: TRS Run_Status (always write if run_result provided)
  if (!is.null(run_result)) {
    # Source TRS run status writer if not already loaded
    tryCatch({
      if (!exists("turas_write_run_status_sheet", mode = "function")) {
        trs_writer_path <- file.path(dirname(getwd()), "shared", "lib", "trs_run_status_writer.R")
        if (!file.exists(trs_writer_path)) {
          trs_writer_path <- file.path(getwd(), "modules", "shared", "lib", "trs_run_status_writer.R")
        }
        if (file.exists(trs_writer_path)) {
          source(trs_writer_path)
        }
      }
      if (exists("turas_write_run_status_sheet", mode = "function")) {
        turas_write_run_status_sheet(wb, run_result)
      }
    }, error = function(e) {
      message(sprintf("[TRS INFO] CONF_RUN_STATUS_WRITE_FAILED: Could not write Run_Status sheet: %s", e$message))
    })
  }

  # Save workbook (TRS v1.0: Use atomic save if available)
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "CONF")
    if (!save_result$success) {
      confidence_refuse(
        code = "IO_EXCEL_SAVE_FAILED",
        title = "Failed to Save Excel File",
        problem = sprintf("Failed to save Excel file: %s", save_result$error),
        why_it_matters = "Output file could not be written to disk.",
        how_to_fix = c(
          "Check file is not open in Excel",
          "Verify output directory exists",
          "Check write permissions",
          "Ensure sufficient disk space"
        ),
        details = sprintf("Output path: %s", output_path)
      )
    }
    message(sprintf("\n[TRS INFO] Output written to: %s", output_path))
  } else {
    # Fallback to direct save
    tryCatch({
      openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
      message(sprintf("\n[TRS INFO] Output written to: %s", output_path))
    }, error = function(e) {
      confidence_refuse(
        code = "IO_EXCEL_SAVE_FAILED",
        title = "Failed to Save Excel File",
        problem = sprintf("Failed to save Excel file: %s", conditionMessage(e)),
        why_it_matters = "Output file could not be written to disk.",
        how_to_fix = c(
          "Check file is not open in Excel",
          "Verify output directory exists",
          "Check write permissions",
          "Ensure sufficient disk space"
        ),
        details = sprintf("Output path: %s", output_path)
      )
    })
  }

  invisible(TRUE)
}
