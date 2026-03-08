# ==============================================================================
# OUTPUT GENERATOR - TURAS V10.1
# ==============================================================================
# Functions for generating Excel output with confidence analysis results
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Refactoring release (2025-12-29)
#          - Added output_helpers.R for common patterns
#          - Improved code organization
#          - Minor cleanup
#
# Turas v10.0 - Initial release (2025-11-13)
#          - Multi-sheet Excel workbook generation
#          - Decimal separator support (period or comma)
#          - Summary, detailed results, methodology, and warnings
#          - Professional formatting with openxlsx
#
# OUTPUT STRUCTURE:
# Sheet 1: Summary - High-level overview
# Sheet 2: Study_Level - DEFF and effective sample size
# Sheet 3: Proportions_Detail - All proportion confidence intervals
# Sheet 4: Means_Detail - All mean confidence intervals
# Sheet 5: Methodology - Statistical methods documentation
# Sheet 6: Warnings - Data quality and calculation warnings
# Sheet 7: Inputs - Configuration summary
#
# DECIMAL SEPARATOR:
# - All numeric output formatted with user-specified separator (. or ,)
# - Applied at final output stage only
# - Internal calculations always use period
#
# DEPENDENCIES:
# - openxlsx (for Excel writing)
# - utils.R
# - output_helpers.R (optional - for common patterns)
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

# Canonical definition in utils.R; fallback if sourced independently
if (!exists("source_if_exists", mode = "function")) {
  source_if_exists <- function(file_path) {
    if (file.exists(file_path)) {
      source(file_path)
    } else if (file.exists(file.path("R", file_path))) {
      source(file.path("R", file_path))
    } else if (file.exists(file.path("..", "R", file_path))) {
      source(file.path("..", "R", file_path))
    }
  }
}

source_if_exists("utils.R")
source_if_exists("output_helpers.R")

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
#' @param config List. Configuration settings
#' @param warnings Character vector. Any warnings generated during analysis
#' @param decimal_sep Character. Decimal separator ("." or ",")
#'
#' @return Logical. TRUE if successful (invisible)
#'
#' @examples
#' write_confidence_output(
#'   output_path = "output/confidence_results.xlsx",
#'   study_level_stats = study_stats,
#'   proportion_results = prop_results,
#'   mean_results = mean_results,
#'   config = config,
#'   warnings = warnings,
#'   decimal_sep = "."
#' )
#'
#' @author Confidence Module Team
#' @date 2025-11-13
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


# ==============================================================================
# SHEET 1: SUMMARY
# ==============================================================================

#' Add summary sheet to workbook (internal)
#' @keywords internal
add_summary_sheet <- function(wb, study_stats, prop_results, mean_results,
                               nps_results, config, warnings, decimal_sep) {

  openxlsx::addWorksheet(wb, "Summary")

  # Title
  row <- 1
  openxlsx::writeData(wb, "Summary", "TURAS CONFIDENCE ANALYSIS - SUMMARY",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 2

  # Analysis Info
  openxlsx::writeData(wb, "Summary", "Analysis Information",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  info_df <- data.frame(
    Setting = c("Date", "Module Version", "Confidence Level", "Decimal Separator"),
    Value = c(
      format(Sys.Date(), "%Y-%m-%d"),
      OUTPUT_VERSION,
      ifelse(!is.null(config$confidence_level),
             format_decimal(config$confidence_level, decimal_sep, 2),
             "0.95"),
      decimal_sep
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Summary", info_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)
  row <- row + nrow(info_df) + 2

  # Study-Level Summary
  if (!is.null(study_stats) && nrow(study_stats) > 0) {
    openxlsx::writeData(wb, "Summary", "Study-Level Statistics",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    # Write numeric data (not converted to strings)
    openxlsx::writeData(wb, "Summary", study_stats, startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Apply Excel number formatting to preserve numeric values
    apply_numeric_formatting(wb, "Summary", row + 1, 1, study_stats, decimal_sep)

    row <- row + nrow(study_stats) + 2
  }

  # Results Summary
  openxlsx::writeData(wb, "Summary", "Results Summary",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Summary",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  summary_df <- data.frame(
    Metric = c("Proportions Analyzed", "Means Analyzed", "NPS Analyzed", "Total Questions"),
    Count = c(
      length(prop_results),
      length(mean_results),
      length(nps_results),
      length(prop_results) + length(mean_results) + length(nps_results)
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Summary", summary_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)
  row <- row + nrow(summary_df) + 2

  # Warnings Summary
  if (length(warnings) > 0) {
    openxlsx::writeData(wb, "Summary", "Warnings",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold",
                                                     fontColour = "#FF0000"),
                       rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Summary",
                        sprintf("%d warnings detected - see Warnings sheet for details",
                                length(warnings)),
                        startCol = 1, startRow = row)
  } else {
    openxlsx::writeData(wb, "Summary", "No Warnings",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold",
                                                     fontColour = "#008000"),
                       rows = row, cols = 1)
  }
  row <- row + 3

  # Plain-English guide
  write_callout_block(wb, "Summary", row, c(
    "HOW TO READ THIS REPORT",
    "",
    "This report presents the results of your confidence analysis. It tells you how",
    "precise your survey estimates are and how much they might differ from the true",
    "population values.",
    "",
    "Key concepts:",
    "  Confidence Interval (CI): A range of values likely to contain the true",
    "  population value. A 95% CI means that if you repeated this survey 100 times,",
    "  about 95 of those intervals would contain the true value.",
    "",
    "  Margin of Error (MOE): Half the width of the confidence interval. A smaller",
    "  MOE means a more precise estimate.",
    "",
    "  Effective Sample Size: When survey weights are applied, some respondents",
    "  count more than others. The effective n tells you how many unweighted",
    "  respondents your weighted sample is equivalent to.",
    "",
    "IMPORTANT ASSUMPTIONS:",
    "  The margin of error assumes a RANDOM (probability) sample. If your sample",
    "  was collected through convenience, online panels, or other non-random methods,",
    "  the MOE does not apply in the traditional sense. Non-response bias and",
    "  coverage error may affect results beyond what the CI captures.",
    "",
    "  See the Methodology sheet for details on each statistical method used."
  ))

  # Auto-size columns
  openxlsx::setColWidths(wb, "Summary", cols = 1:2, widths = "auto")
}


# ==============================================================================
# SHEET 2: STUDY LEVEL
# ==============================================================================

#' Add study-level statistics sheet (internal)
#' @keywords internal
add_study_level_sheet <- function(wb, study_stats, decimal_sep) {

  openxlsx::addWorksheet(wb, "Study_Level")

  # Title
  openxlsx::writeData(wb, "Study_Level", "STUDY-LEVEL STATISTICS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Study_Level",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Write numeric data (not converted to strings)
  openxlsx::writeData(wb, "Study_Level", study_stats, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Apply Excel number formatting to preserve numeric values
  apply_numeric_formatting(wb, "Study_Level", 4, 1, study_stats, decimal_sep)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Study_Level", header_style, rows = 3,
                     cols = 1:ncol(study_stats), gridExpand = TRUE)

  # Interpretation notes
  row <- 3 + nrow(study_stats) + 2
  openxlsx::writeData(wb, "Study_Level", "INTERPRETATION:", startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Study_Level",
                     style = openxlsx::createStyle(textDecoration = "bold"),
                     rows = row, cols = 1)

  row <- row + 1

  write_callout_block(wb, "Study_Level", row, c(
    "WHAT THIS MEANS",
    "",
    "The Design Effect (DEFF) measures how much precision you lose because of",
    "weighting. A DEFF of 1.00 means no loss at all. A DEFF of 1.20 means you",
    "lose about 20% of your precision, as if you had surveyed 20% fewer people.",
    "",
    "  1.00 = No loss of precision (no weighting or perfectly balanced weights)",
    "  1.05-1.20 = Modest loss - your weighted results are still very reliable",
    "  1.20-2.00 = Moderate loss - consider whether weighting is adding value",
    "  >2.00 = Substantial loss - weighting is significantly reducing precision",
    "",
    "The Effective Sample Size is your actual sample after accounting for",
    "weighting. For example, if you surveyed 1,000 people but DEFF = 1.25,",
    "your effective n is about 800. This is the number used in CI calculations.",
    "",
    "IMPORTANT: These statistics only measure the impact of weighting on",
    "precision. They do NOT account for non-response bias, coverage errors,",
    "or measurement errors. A large effective n does not guarantee your",
    "results are representative of the population.",
    "",
    "Weight CV (Coefficient of Variation):",
    "  <0.20 = Modest variation in weights",
    "  0.20-0.30 = Moderate variation",
    "  >0.30 = High variation - a few respondents may dominate results"
  ))

  # Auto-size columns
  openxlsx::setColWidths(wb, "Study_Level", cols = 1:ncol(study_stats), widths = "auto")
}


# ==============================================================================
# SHEET 3: REPRESENTATIVENESS & WEIGHTS
# ==============================================================================

#' Add representativeness and weight diagnostics sheet (internal)
#' @keywords internal
add_representativeness_sheet <- function(wb, study_stats, decimal_sep) {

  # Extract margin comparison and weight concentration from attributes
  margin_comp <- attr(study_stats, "margin_comparison")
  weight_conc <- attr(study_stats, "weight_concentration")

  # Skip if no data to show
  if (is.null(margin_comp) && is.null(weight_conc)) {
    return(invisible(wb))
  }

  openxlsx::addWorksheet(wb, "Representativeness_Weights")

  row <- 1

  # Title
  openxlsx::writeData(wb, "Representativeness_Weights",
                      "REPRESENTATIVENESS & WEIGHT DIAGNOSTICS",
                      startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Representativeness_Weights",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 2

  # Block A: Weight Concentration Diagnostics
  if (!is.null(weight_conc) && nrow(weight_conc) > 0) {
    openxlsx::writeData(wb, "Representativeness_Weights",
                        "A. Weight Distribution & Concentration",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Representativeness_Weights",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Representativeness_Weights",
                        weight_conc,
                        startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Apply numeric formatting
    apply_numeric_formatting(wb, "Representativeness_Weights",
                             row + 1, 1, weight_conc, decimal_sep)

    # Header style
    header_style <- openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      fgFill = "#4F81BD",
      fontColour = "#FFFFFF",
      border = "TopBottomLeftRight"
    )
    openxlsx::addStyle(wb, "Representativeness_Weights", header_style,
                       rows = row, cols = 1:ncol(weight_conc), gridExpand = TRUE)

    row <- row + nrow(weight_conc) + 2

    # Interpretation notes for weight concentration
    openxlsx::writeData(wb, "Representativeness_Weights",
                        "Interpretation:",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Representativeness_Weights",
                       style = openxlsx::createStyle(textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    notes_conc <- c(
      "Weight Concentration (Top 5% Share):",
      "  LOW (< 15%): Healthy weight distribution",
      "  MODERATE (15-25%): Acceptable concentration",
      "  HIGH (> 25%): Concerning - few cases dominate weighted sample"
    )

    for (note in notes_conc) {
      openxlsx::writeData(wb, "Representativeness_Weights", note,
                          startCol = 1, startRow = row)
      row <- row + 1
    }

    row <- row + 2
  }

  # Block B: Margin Comparison (Target vs Actual)
  if (!is.null(margin_comp) && nrow(margin_comp) > 0) {
    openxlsx::writeData(wb, "Representativeness_Weights",
                        "B. Population Margin Comparison (Target vs Weighted Sample)",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Representativeness_Weights",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Representativeness_Weights",
                        margin_comp,
                        startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Apply numeric formatting
    apply_numeric_formatting(wb, "Representativeness_Weights",
                             row + 1, 1, margin_comp, decimal_sep)

    # Header style
    header_style <- openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      fgFill = "#4F81BD",
      fontColour = "#FFFFFF",
      border = "TopBottomLeftRight"
    )
    openxlsx::addStyle(wb, "Representativeness_Weights", header_style,
                       rows = row, cols = 1:ncol(margin_comp), gridExpand = TRUE)

    # Conditional formatting on Flag column
    flag_col <- which(colnames(margin_comp) == "Flag")
    if (length(flag_col) == 1) {
      n_rows <- nrow(margin_comp)

      # RED flag formatting
      openxlsx::conditionalFormatting(
        wb, "Representativeness_Weights",
        cols = flag_col,
        rows = (row + 1):(row + n_rows),
        type = "contains",
        rule = "RED",
        style = openxlsx::createStyle(fontColour = "#9C0006", bgFill = "#FFC7CE")
      )

      # AMBER flag formatting
      openxlsx::conditionalFormatting(
        wb, "Representativeness_Weights",
        cols = flag_col,
        rows = (row + 1):(row + n_rows),
        type = "contains",
        rule = "AMBER",
        style = openxlsx::createStyle(fontColour = "#9C5700", bgFill = "#FFEB9C")
      )

      # GREEN flag formatting
      openxlsx::conditionalFormatting(
        wb, "Representativeness_Weights",
        cols = flag_col,
        rows = (row + 1):(row + n_rows),
        type = "contains",
        rule = "GREEN",
        style = openxlsx::createStyle(fontColour = "#006100", bgFill = "#C6EFCE")
      )
    }

    row <- row + nrow(margin_comp) + 2

    # Interpretation notes for margin comparison
    openxlsx::writeData(wb, "Representativeness_Weights",
                        "Interpretation:",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Representativeness_Weights",
                       style = openxlsx::createStyle(textDecoration = "bold"),
                       rows = row, cols = 1)
    row <- row + 1

    notes_margin <- c(
      "Difference from Target (in percentage points):",
      "  GREEN: |Difference| < 2pp - Excellent representativeness",
      "  AMBER: |Difference| 2-5pp - Acceptable, minor deviation",
      "  RED: |Difference| >= 5pp - Concerning, substantial deviation",
      "",
      "Diff_pp = Weighted_Sample_Pct - Target_Pct",
      "Positive values: Over-represented vs target",
      "Negative values: Under-represented vs target"
    )

    for (note in notes_margin) {
      openxlsx::writeData(wb, "Representativeness_Weights", note,
                          startCol = 1, startRow = row)
      row <- row + 1
    }
  }

  # Auto-size columns
  openxlsx::setColWidths(wb, "Representativeness_Weights", cols = 1:12, widths = "auto")

  invisible(wb)
}


# ==============================================================================
# SHEET 4: PROPORTIONS DETAIL
# ==============================================================================

#' Add proportions detail sheet (internal)
#' @keywords internal
add_proportions_detail_sheet <- function(wb, prop_results, decimal_sep) {

  openxlsx::addWorksheet(wb, "Proportions_Detail")

  # Title
  openxlsx::writeData(wb, "Proportions_Detail", "PROPORTIONS - DETAILED RESULTS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Proportions_Detail",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Convert results list to data frame
  prop_df <- build_proportions_dataframe(prop_results)

  if (nrow(prop_df) == 0) {
    openxlsx::writeData(wb, "Proportions_Detail", "No proportion analyses performed",
                        startCol = 1, startRow = 3)
    return(invisible(NULL))
  }

  # Write numeric data (not converted to strings)
  openxlsx::writeData(wb, "Proportions_Detail", prop_df, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Apply Excel number formatting to preserve numeric values
  apply_numeric_formatting(wb, "Proportions_Detail", 4, 1, prop_df, decimal_sep)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Proportions_Detail", header_style, rows = 3,
                     cols = 1:ncol(prop_df), gridExpand = TRUE)

  # Callout rows below the data
  callout_row <- 3 + nrow(prop_df) + 2
  write_callout_block(wb, "Proportions_Detail", callout_row, c(
    "HOW TO READ THESE RESULTS",
    "",
    "Each row shows a survey question analysed as a proportion (percentage).",
    "The Proportion column is the observed percentage in your sample.",
    "",
    "Confidence intervals tell you the range where the TRUE population",
    "value likely falls. For example, if the proportion is 0.45 and the 95%",
    "CI is [0.40, 0.50], there is a 95% chance the real value is between",
    "40% and 50%.",
    "",
    "Methods available:",
    "  MOE (Normal): Standard margin of error. Simple and widely understood,",
    "  but can give impossible values (below 0% or above 100%) for extreme",
    "  proportions. Works best when p is between 20% and 80%.",
    "",
    "  Wilson Score: Better than MOE for extreme proportions (very high or",
    "  very low percentages). Always gives valid intervals within [0%, 100%].",
    "  Recommended for proportions below 10% or above 90%.",
    "",
    "  Bootstrap: Makes no assumptions about your data distribution. Works",
    "  by re-analysing random subsets thousands of times. Especially reliable",
    "  for unusual distributions or small samples.",
    "",
    "  Bayesian: Combines your survey data with prior knowledge (if any).",
    "  Useful for tracking studies where previous wave data can inform the",
    "  current estimate.",
    "",
    "IMPORTANT: All confidence intervals assume a random (probability) sample.",
    "If your sample was collected through convenience, online panels, or",
    "snowball sampling, the intervals may understate the true uncertainty."
  ))

  # Auto-size columns
  openxlsx::setColWidths(wb, "Proportions_Detail", cols = 1:ncol(prop_df), widths = "auto")
}


#' Build proportions dataframe from results list (internal)
#' @keywords internal
build_proportions_dataframe <- function(prop_results) {

  if (length(prop_results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(prop_results)) {
    q_result <- prop_results[[q_id]]

    # Base info
    base_row <- list(
      Question_ID = q_id,
      Category = ifelse(!is.null(q_result$category), q_result$category, "Total"),
      Proportion = ifelse(!is.null(q_result$proportion), q_result$proportion, NA),
      Sample_Size = ifelse(!is.null(q_result$n), q_result$n, NA),
      Effective_n = ifelse(!is.null(q_result$n_eff), q_result$n_eff, NA)
    )

    # MOE
    if (!is.null(q_result$moe_normal)) {
      base_row$MOE_Normal_Lower <- q_result$moe_normal$lower
      base_row$MOE_Normal_Upper <- q_result$moe_normal$upper
      base_row$MOE <- q_result$moe_normal$moe
    }

    # Wilson
    if (!is.null(q_result$wilson)) {
      base_row$Wilson_Lower <- q_result$wilson$lower
      base_row$Wilson_Upper <- q_result$wilson$upper
    }

    # Bootstrap
    if (!is.null(q_result$bootstrap)) {
      base_row$Bootstrap_Lower <- q_result$bootstrap$lower
      base_row$Bootstrap_Upper <- q_result$bootstrap$upper
    }

    # Bayesian
    if (!is.null(q_result$bayesian)) {
      base_row$Bayesian_Lower <- q_result$bayesian$lower
      base_row$Bayesian_Upper <- q_result$bayesian$upper
    }

    rows_list[[length(rows_list) + 1]] <- base_row
  }

  # Combine all rows - use bind_rows to handle mismatched columns
  if (requireNamespace("dplyr", quietly = TRUE)) {
    df <- dplyr::bind_rows(rows_list)
  } else {
    # Fallback: find all unique column names and fill missing ones with NA
    all_cols <- unique(unlist(lapply(rows_list, names)))
    rows_list_filled <- lapply(rows_list, function(row) {
      missing_cols <- setdiff(all_cols, names(row))
      for (col in missing_cols) {
        row[[col]] <- NA
      }
      return(row[all_cols])  # Reorder to match all_cols
    })
    df <- do.call(rbind, lapply(rows_list_filled, function(x) as.data.frame(x, stringsAsFactors = FALSE)))
  }

  return(df)
}


# ==============================================================================
# SHEET 4: MEANS DETAIL
# ==============================================================================

#' Add means detail sheet (internal)
#' @keywords internal
add_means_detail_sheet <- function(wb, mean_results, decimal_sep) {

  openxlsx::addWorksheet(wb, "Means_Detail")

  # Title
  openxlsx::writeData(wb, "Means_Detail", "MEANS - DETAILED RESULTS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Means_Detail",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Convert results list to data frame
  mean_df <- build_means_dataframe(mean_results)

  if (nrow(mean_df) == 0) {
    openxlsx::writeData(wb, "Means_Detail", "No mean analyses performed",
                        startCol = 1, startRow = 3)
    return(invisible(NULL))
  }

  # Write numeric data (not converted to strings)
  openxlsx::writeData(wb, "Means_Detail", mean_df, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Apply Excel number formatting to preserve numeric values
  apply_numeric_formatting(wb, "Means_Detail", 4, 1, mean_df, decimal_sep)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Means_Detail", header_style, rows = 3,
                     cols = 1:ncol(mean_df), gridExpand = TRUE)

  # Callout rows below the data
  callout_row <- 3 + nrow(mean_df) + 2
  write_callout_block(wb, "Means_Detail", callout_row, c(
    "HOW TO READ THESE RESULTS",
    "",
    "Each row shows a survey question analysed as a mean (average).",
    "The Mean column is the observed average in your sample, and SD is",
    "the standard deviation (how spread out the individual responses are).",
    "",
    "Confidence intervals tell you the range where the TRUE population",
    "average likely falls. For example, if the mean is 7.2 and the 95%",
    "CI is [6.8, 7.6], there is a 95% chance the real average is between",
    "6.8 and 7.6.",
    "",
    "Methods available:",
    "  t-Distribution: The standard approach for means. Assumes data is",
    "  roughly bell-shaped (normally distributed). Reliable for most survey",
    "  rating scales when n > 30.",
    "",
    "  Bootstrap: Makes no assumptions about your data distribution. Works",
    "  by re-analysing random subsets thousands of times. Better for skewed",
    "  distributions or small samples.",
    "",
    "  Bayesian: Combines your survey data with prior knowledge (if any).",
    "  The posterior mean may differ from the sample mean if a prior was set.",
    "",
    "SE (Standard Error) measures how precisely the mean is estimated.",
    "Smaller SE = more precise estimate. SE depends on both sample size",
    "and data variability.",
    "",
    "IMPORTANT: All confidence intervals assume a random (probability) sample.",
    "If respondents self-selected into the survey, the CI reflects sampling",
    "variability only and does not capture selection bias."
  ))

  # Auto-size columns
  openxlsx::setColWidths(wb, "Means_Detail", cols = 1:ncol(mean_df), widths = "auto")
}


#' Build means dataframe from results list (internal)
#' @keywords internal
build_means_dataframe <- function(mean_results) {

  if (length(mean_results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(mean_results)) {
    q_result <- mean_results[[q_id]]

    # Base info
    base_row <- list(
      Question_ID = q_id,
      Mean = ifelse(!is.null(q_result$mean), q_result$mean, NA),
      SD = ifelse(!is.null(q_result$sd), q_result$sd, NA),
      Sample_Size = ifelse(!is.null(q_result$n), q_result$n, NA),
      Effective_n = ifelse(!is.null(q_result$n_eff), q_result$n_eff, NA)
    )

    # t-distribution CI
    if (!is.null(q_result$t_dist)) {
      base_row$tDist_Lower <- q_result$t_dist$lower
      base_row$tDist_Upper <- q_result$t_dist$upper
      base_row$SE <- q_result$t_dist$se
      base_row$DF <- q_result$t_dist$df
    }

    # Bootstrap
    if (!is.null(q_result$bootstrap)) {
      base_row$Bootstrap_Lower <- q_result$bootstrap$lower
      base_row$Bootstrap_Upper <- q_result$bootstrap$upper
    }

    # Bayesian
    if (!is.null(q_result$bayesian)) {
      base_row$Bayesian_Lower <- q_result$bayesian$lower
      base_row$Bayesian_Upper <- q_result$bayesian$upper
      base_row$Bayesian_Mean <- q_result$bayesian$post_mean
    }

    rows_list[[length(rows_list) + 1]] <- base_row
  }

  # Combine all rows - use bind_rows to handle mismatched columns
  if (requireNamespace("dplyr", quietly = TRUE)) {
    df <- dplyr::bind_rows(rows_list)
  } else {
    # Fallback: find all unique column names and fill missing ones with NA
    all_cols <- unique(unlist(lapply(rows_list, names)))
    rows_list_filled <- lapply(rows_list, function(row) {
      missing_cols <- setdiff(all_cols, names(row))
      for (col in missing_cols) {
        row[[col]] <- NA
      }
      return(row[all_cols])  # Reorder to match all_cols
    })
    df <- do.call(rbind, lapply(rows_list_filled, function(x) as.data.frame(x, stringsAsFactors = FALSE)))
  }

  return(df)
}


# ==============================================================================
# SHEET 5: NPS DETAIL
# ==============================================================================

#' Add NPS detail sheet (internal)
#' @keywords internal
add_nps_detail_sheet <- function(wb, nps_results, decimal_sep) {

  openxlsx::addWorksheet(wb, "NPS_Detail")

  # Title
  openxlsx::writeData(wb, "NPS_Detail", "NET PROMOTER SCORE - DETAILED RESULTS",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "NPS_Detail",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  # Convert results list to data frame
  nps_df <- build_nps_dataframe(nps_results)

  if (nrow(nps_df) == 0) {
    openxlsx::writeData(wb, "NPS_Detail", "No NPS analyses performed",
                        startCol = 1, startRow = 3)
    return(invisible(NULL))
  }

  # Write numeric data (not converted to strings)
  openxlsx::writeData(wb, "NPS_Detail", nps_df, startCol = 1, startRow = 3,
                      colNames = TRUE, rowNames = FALSE)

  # Apply Excel number formatting to preserve numeric values
  apply_numeric_formatting(wb, "NPS_Detail", 4, 1, nps_df, decimal_sep)

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#4F81BD",
    fontColour = "#FFFFFF",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "NPS_Detail", header_style, rows = 3,
                     cols = 1:ncol(nps_df), gridExpand = TRUE)

  # Callout rows below the data
  callout_row <- 3 + nrow(nps_df) + 2
  write_callout_block(wb, "NPS_Detail", callout_row, c(
    "HOW TO READ THESE RESULTS",
    "",
    "NPS (Net Promoter Score) = % Promoters - % Detractors.",
    "It ranges from -100 (everyone is a detractor) to +100 (everyone is a",
    "promoter). Scores above 0 are generally positive, above 50 are excellent.",
    "",
    "Confidence intervals show the range where the TRUE NPS likely falls.",
    "NPS can be volatile with small samples because it depends on the",
    "difference between two proportions.",
    "",
    "Rule of thumb for NPS precision:",
    "  n < 100: NPS can swing by 15-20 points between samples",
    "  n = 200-500: Typical MOE of 7-10 points",
    "  n > 1000: MOE under 4 points",
    "",
    "IMPORTANT: NPS confidence intervals assume a random sample. If your",
    "respondents were not randomly selected, the interval does not account",
    "for the bias introduced by sample selection."
  ))

  # Auto-size columns
  openxlsx::setColWidths(wb, "NPS_Detail", cols = 1:ncol(nps_df), widths = "auto")
}


#' Build NPS dataframe from results list (internal)
#' @keywords internal
build_nps_dataframe <- function(nps_results) {

  if (length(nps_results) == 0) {
    return(data.frame())
  }

  rows_list <- list()

  for (q_id in names(nps_results)) {
    q_result <- nps_results[[q_id]]

    # Base info
    base_row <- list(
      Question_ID = q_id,
      NPS_Score = ifelse(!is.null(q_result$nps_score), q_result$nps_score, NA),
      Pct_Promoters = ifelse(!is.null(q_result$pct_promoters), q_result$pct_promoters, NA),
      Pct_Detractors = ifelse(!is.null(q_result$pct_detractors), q_result$pct_detractors, NA),
      Sample_Size = ifelse(!is.null(q_result$n), q_result$n, NA),
      Effective_n = ifelse(!is.null(q_result$n_eff), q_result$n_eff, NA)
    )

    # Normal approximation CI (check both field names for compatibility)
    nps_normal <- q_result$moe_normal %||% q_result$normal_ci
    if (!is.null(nps_normal)) {
      base_row$Normal_Lower <- nps_normal$lower
      base_row$Normal_Upper <- nps_normal$upper
      base_row$SE <- nps_normal$se
    }

    # Bootstrap
    if (!is.null(q_result$bootstrap)) {
      base_row$Bootstrap_Lower <- q_result$bootstrap$lower
      base_row$Bootstrap_Upper <- q_result$bootstrap$upper
    }

    # Bayesian
    if (!is.null(q_result$bayesian)) {
      base_row$Bayesian_Lower <- q_result$bayesian$lower
      base_row$Bayesian_Upper <- q_result$bayesian$upper
      base_row$Bayesian_Mean <- q_result$bayesian$post_mean
    }

    rows_list[[length(rows_list) + 1]] <- base_row
  }

  # Combine all rows - use bind_rows to handle mismatched columns
  if (requireNamespace("dplyr", quietly = TRUE)) {
    df <- dplyr::bind_rows(rows_list)
  } else {
    # Fallback: find all unique column names and fill missing ones with NA
    all_cols <- unique(unlist(lapply(rows_list, names)))
    rows_list_filled <- lapply(rows_list, function(row) {
      missing_cols <- setdiff(all_cols, names(row))
      for (col in missing_cols) {
        row[[col]] <- NA
      }
      return(row[all_cols])  # Reorder to match all_cols
    })
    df <- do.call(rbind, lapply(rows_list_filled, function(x) as.data.frame(x, stringsAsFactors = FALSE)))
  }

  return(df)
}


# ==============================================================================
# SHEET 6: METHODOLOGY
# ==============================================================================

#' Add methodology documentation sheet (internal)
#' @keywords internal
add_methodology_sheet <- function(wb) {

  openxlsx::addWorksheet(wb, "Methodology")

  # Title
  openxlsx::writeData(wb, "Methodology", "STATISTICAL METHODOLOGY",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Methodology",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  # Methodology content — plain-English first, then technical detail
  methodology_text <- c(
    "ABOUT CONFIDENCE ANALYSIS",
    "",
    "Confidence analysis answers the question: 'How much can I trust these",
    "numbers?' Every survey is based on a sample of people, not the entire",
    "population. Confidence intervals tell you the range of values where",
    "the true population answer likely falls.",
    "",
    "For example, if 45% of your sample chose Option A, and the 95%",
    "confidence interval is [40%, 50%], you can say: 'We are 95% confident",
    "that the true percentage is between 40% and 50%.'",
    "",
    "----------------------------------------------------------------------",
    "",
    "METHODS FOR PROPORTIONS (Percentages)",
    "",
    "1. Normal Approximation (Margin of Error)",
    "   What it does: The standard 'plus or minus' margin of error.",
    "   When to use: Works well for most proportions between 20% and 80%",
    "   with samples of 100+.",
    "   Limitation: Can produce impossible results (below 0% or above 100%)",
    "   for extreme proportions. Not reliable when n*p < 10.",
    "   Formula: MOE = z * sqrt(p*(1-p)/n)",
    "",
    "2. Wilson Score Interval",
    "   What it does: A smarter version of the margin of error that always",
    "   stays within [0%, 100%].",
    "   When to use: Always better than Normal for extreme proportions",
    "   (below 10% or above 90%) and small samples.",
    "   Limitation: Slightly more complex to calculate, but modern software",
    "   handles this automatically.",
    "",
    "3. Bootstrap",
    "   What it does: Re-analyses your data thousands of times by randomly",
    "   selecting subsets (with replacement). The range of these results",
    "   becomes the confidence interval.",
    "   When to use: When you are unsure whether standard assumptions hold,",
    "   or when dealing with complex survey designs.",
    "   Limitation: Results vary slightly between runs (controlled by seed).",
    "   Computationally intensive for very large datasets.",
    "",
    "4. Bayesian (Beta-Binomial)",
    "   What it does: Combines your survey data with prior knowledge to",
    "   produce a 'credible interval'. With no prior, it gives results",
    "   similar to other methods.",
    "   When to use: Tracking studies where previous wave data provides",
    "   a useful starting point.",
    "   Limitation: Results depend on prior specification. A poorly chosen",
    "   prior can bias the result.",
    "   Technical: Posterior = Beta(alpha + x, beta + n - x)",
    "",
    "----------------------------------------------------------------------",
    "",
    "METHODS FOR MEANS (Averages)",
    "",
    "1. t-Distribution",
    "   What it does: The standard approach for average values.",
    "   When to use: Most survey rating scales (e.g. 1-10 satisfaction)",
    "   with n > 30. Works well when data is roughly symmetric.",
    "   Limitation: Less reliable for highly skewed distributions or",
    "   very small samples.",
    "   Formula: CI = mean +/- t(df) * SE, where SE = sd / sqrt(n_eff)",
    "",
    "2. Bootstrap",
    "   What it does: Same approach as proportion bootstrap - re-analyses",
    "   data thousands of times.",
    "   When to use: Skewed distributions, small samples, or when the",
    "   bell-curve assumption is questionable.",
    "",
    "3. Bayesian (Normal-Normal)",
    "   What it does: Combines data with prior knowledge using precision-",
    "   weighted averaging.",
    "   When to use: Tracking studies with informative priors.",
    "",
    "----------------------------------------------------------------------",
    "",
    "NET PROMOTER SCORE (NPS)",
    "",
    "Formula: NPS = %Promoters - %Detractors (scale: -100 to +100)",
    "  Promoters: Scores 9-10 (on 0-10 scale)",
    "  Detractors: Scores 0-6",
    "  Passives: Scores 7-8 (excluded from NPS calculation)",
    "",
    "NPS is inherently volatile because it depends on the difference",
    "between two proportions. Expect wider confidence intervals than",
    "for simple proportions.",
    "",
    "----------------------------------------------------------------------",
    "",
    "WEIGHTING AND EFFECTIVE SAMPLE SIZE",
    "",
    "When weights are applied, some respondents count more than others.",
    "This reduces precision compared to an unweighted sample of the same",
    "size. The Design Effect (DEFF) quantifies this loss.",
    "",
    "  DEFF = 1 + CV^2 (where CV = coefficient of variation of weights)",
    "  Effective n = (Sum of weights)^2 / Sum(weights^2)  [Kish, 1965]",
    "",
    "All standard errors in this report use effective n for weighted data.",
    "",
    "----------------------------------------------------------------------",
    "",
    "CRITICAL ASSUMPTIONS AND LIMITATIONS",
    "",
    "1. RANDOM SAMPLING: All confidence intervals assume data was collected",
    "   through a probability (random) sampling method. If your sample is a",
    "   convenience sample, online panel, or collected through non-random",
    "   means, the intervals are technically invalid. They still indicate",
    "   variability, but they do NOT capture selection bias.",
    "",
    "2. NON-RESPONSE: If certain groups are less likely to respond, the",
    "   sample may not represent the population even with random selection.",
    "   Confidence intervals do not account for non-response bias.",
    "",
    "3. MEASUREMENT ERROR: CIs measure sampling variability only. They",
    "   cannot detect poorly worded questions, social desirability bias,",
    "   or other systematic measurement errors.",
    "",
    "----------------------------------------------------------------------",
    "",
    "REFERENCES",
    "",
    "Kish, L. (1965). Survey Sampling. Wiley.",
    "Agresti, A., & Coull, B. A. (1998). Approximate is better than exact.",
    "Wilson, E. B. (1927). Probable inference and statistical inference.",
    "Efron, B., & Tibshirani, R. J. (1994). An Introduction to the Bootstrap."
  )

  for (line in methodology_text) {
    openxlsx::writeData(wb, "Methodology", line, startCol = 1, startRow = row)
    row <- row + 1
  }

  # Auto-size column
  openxlsx::setColWidths(wb, "Methodology", cols = 1, widths = 80)
}


# ==============================================================================
# SHEET 6: WARNINGS
# ==============================================================================

#' Add warnings sheet (internal)
#' @keywords internal
add_warnings_sheet <- function(wb, warnings) {

  openxlsx::addWorksheet(wb, "Warnings")

  # Title
  openxlsx::writeData(wb, "Warnings", "WARNINGS AND DATA QUALITY NOTES",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Warnings",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  if (length(warnings) == 0) {
    openxlsx::writeData(wb, "Warnings", "No warnings detected",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Warnings",
                       style = openxlsx::createStyle(fontSize = 12, fontColour = "#008000"),
                       rows = row, cols = 1)
  } else {
    # Build warnings with guidance
    guidance <- vapply(warnings, classify_warning_guidance, character(1))

    warnings_df <- data.frame(
      Number = seq_along(warnings),
      Warning = warnings,
      What_To_Do = guidance,
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Warnings", warnings_df, startCol = 1, startRow = row,
                        colNames = TRUE, rowNames = FALSE)

    # Header style
    header_style <- openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      fgFill = "#FF6B6B",
      fontColour = "#FFFFFF"
    )
    openxlsx::addStyle(wb, "Warnings", header_style, rows = row,
                       cols = 1:3, gridExpand = TRUE)

    # Auto-size columns
    openxlsx::setColWidths(wb, "Warnings", cols = 1, widths = 8)
    openxlsx::setColWidths(wb, "Warnings", cols = 2, widths = 60)
    openxlsx::setColWidths(wb, "Warnings", cols = 3, widths = 60)
  }
}


# ==============================================================================
# SHEET 7: INPUTS
# ==============================================================================

#' Add inputs/configuration sheet (internal)
#' @keywords internal
add_inputs_sheet <- function(wb, config, decimal_sep) {

  openxlsx::addWorksheet(wb, "Inputs")

  # Title
  openxlsx::writeData(wb, "Inputs", "INPUT CONFIGURATION",
                      startCol = 1, startRow = 1)
  openxlsx::addStyle(wb, "Inputs",
                     style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                     rows = 1, cols = 1)

  row <- 3

  # Study Settings
  openxlsx::writeData(wb, "Inputs", "Study Settings:", startCol = 1, startRow = row)
  openxlsx::addStyle(wb, "Inputs",
                     style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold"),
                     rows = row, cols = 1)
  row <- row + 1

  settings_df <- data.frame(
    Setting = c(
      "Confidence Level",
      "Bootstrap Iterations",
      "Multiple Comparison Adjustment",
      "Decimal Separator",
      "Calculate Effective Sample Size"
    ),
    Value = c(
      ifelse(!is.null(config$confidence_level),
             format_decimal(config$confidence_level, decimal_sep, 2), "0.95"),
      ifelse(!is.null(config$bootstrap_iterations),
             as.character(config$bootstrap_iterations), "5000"),
      ifelse(!is.null(config$multiple_comparison_method),
             config$multiple_comparison_method, "None"),
      decimal_sep,
      ifelse(!is.null(config$calculate_effective_n),
             ifelse(config$calculate_effective_n, "Yes", "No"), "Yes")
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Inputs", settings_df, startCol = 1, startRow = row,
                      colNames = TRUE, rowNames = FALSE)

  # Auto-size columns
  openxlsx::setColWidths(wb, "Inputs", cols = 1:2, widths = "auto")
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Create Excel number format string with decimal separator (internal)
#'
#' Creates an Excel number format code. Note that the actual decimal separator
#' displayed depends on Excel's regional settings, not the format code itself.
#'
#' @param decimal_places Integer. Number of decimal places
#' @param decimal_sep Character. Ignored - kept for API compatibility
#' @return Character. Excel number format code
#' @keywords internal
create_excel_number_format <- function(decimal_places = 2, decimal_sep = ".") {

  if (decimal_places == 0) {
    return("0")
  }

  # IMPORTANT: Excel format codes always use period for decimal position
  # The actual separator displayed (period or comma) depends on Excel's locale
  # We cannot control this through the format code alone
  zeros <- paste(rep("0", decimal_places), collapse = "")
  format_str <- paste0("0.", zeros)  # Always use period in format code

  return(format_str)
}


#' Apply Excel number formatting to numeric columns in dataframe region (internal)
#'
#' Applies Excel cell styles with number formatting to preserve numeric values.
#' Does NOT convert to character strings - keeps values numeric.
#'
#' @param wb Workbook object
#' @param sheet Sheet name
#' @param start_row Starting row
#' @param start_col Starting column
#' @param df Data frame to format
#' @param decimal_sep Character. "." or ","
#' @keywords internal
apply_numeric_formatting <- function(wb, sheet, start_row, start_col, df, decimal_sep) {

  if (!is.data.frame(df) || nrow(df) == 0) {
    return(invisible(NULL))
  }

  # Apply formatting to each numeric column
  for (col_idx in seq_along(df)) {
    col_data <- df[[col_idx]]
    col_name <- names(df)[col_idx]

    if (is.numeric(col_data)) {
      # Determine appropriate decimal places
      digits <- 2

      # Use more precision for small values (SE, MOE, CV, DEFF, etc.)
      if (any(grepl("SE|MOE|CV|DEFF", col_name, ignore.case = TRUE))) {
        digits <- 3
      }

      # Create Excel number format
      num_format <- create_excel_number_format(digits, decimal_sep)
      num_style <- openxlsx::createStyle(numFmt = num_format)

      # Apply to all data rows in this column
      excel_col <- start_col + col_idx - 1
      data_rows <- start_row:(start_row + nrow(df) - 1)

      openxlsx::addStyle(wb, sheet, num_style,
                        rows = data_rows,
                        cols = excel_col,
                        gridExpand = TRUE,
                        stack = TRUE)
    }
  }

  invisible(NULL)
}


#' Classify a warning and return actionable guidance
#'
#' Matches warning text to known patterns and returns plain-English guidance
#' for what the user should do about each warning.
#'
#' @param warning_text Character. The warning message
#' @return Character. Guidance text
#' @keywords internal
classify_warning_guidance <- function(warning_text) {
  w <- tolower(warning_text)

  if (grepl("effective.?n|n_eff|sample.?size.*(small|low|insuff)", w)) {
    return("Consider increasing your sample size. Results with small effective n are unreliable. Treat estimates as directional only.")
  }
  if (grepl("deff|design.?effect.*(high|large)", w)) {
    return("High DEFF means weighting is reducing precision significantly. Review whether all weighting variables are necessary, or consider collecting more data.")
  }
  if (grepl("weight.*(extreme|high|conc|domin)", w)) {
    return("Some respondents have very large weights, meaning a few people heavily influence results. Consider capping extreme weights or reviewing your weighting scheme.")
  }
  if (grepl("zero.?cell|zero.?count|no.?(obs|respon)", w)) {
    return("Some categories have no respondents. CIs cannot be calculated for empty cells. Consider combining sparse categories or increasing sample coverage.")
  }
  if (grepl("ci.?width.*(wide|large)|moe.*(large|wide)", w)) {
    return("Wide confidence intervals mean low precision. The true value could be anywhere in a large range. More data or a more targeted sample would narrow the interval.")
  }
  if (grepl("bootstrap.*(fail|converg|warn)", w)) {
    return("Bootstrap resampling encountered issues. Results may be less reliable. Check data for extreme outliers or consider using a different CI method.")
  }
  if (grepl("prior.*(invalid|conflict|implaus)", w)) {
    return("The Bayesian prior may not be appropriate for this data. Bayesian results will be unreliable. Consider using an uninformed prior or check prior settings.")
  }
  if (grepl("normal.?approx|n\\*p.*(small|less|low)", w)) {
    return("The normal approximation may not be accurate for this data. Use Wilson Score or Bootstrap intervals instead, which are more reliable for extreme proportions or small samples.")
  }
  if (grepl("convergence|iteration|did not converge", w)) {
    return("The algorithm did not fully converge. Results may be approximate. Consider increasing bootstrap iterations or checking data quality.")
  }

  # Default guidance
  "Review this warning in context. If it affects a question important to your analysis, consider alternative methods or collecting additional data."
}


#' Write a callout block to an Excel sheet
#'
#' Writes plain-English interpretation text with light blue background styling.
#' Used across sheets to provide marketer-friendly explanations.
#'
#' @param wb Workbook object
#' @param sheet Sheet name
#' @param start_row Starting row for the callout
#' @param lines Character vector, one element per row
#' @return Next available row after the callout block (invisible)
#' @keywords internal
write_callout_block <- function(wb, sheet, start_row, lines) {
  callout_style <- openxlsx::createStyle(
    fontSize = 10,
    fontColour = "#1a3a5c",
    fgFill = "#f0f9ff",
    wrapText = TRUE
  )
  callout_bold <- openxlsx::createStyle(
    fontSize = 10,
    fontColour = "#1a3a5c",
    fgFill = "#f0f9ff",
    textDecoration = "bold",
    wrapText = TRUE
  )

  row <- start_row
  for (line in lines) {
    openxlsx::writeData(wb, sheet, line, startCol = 1, startRow = row)
    # Bold lines that look like headings (all caps or end with ":")
    if (nzchar(line) && (grepl("^[A-Z ]+:?$", line) || grepl(":$", trimws(line)))) {
      openxlsx::addStyle(wb, sheet, callout_bold, rows = row, cols = 1)
    } else if (nzchar(line)) {
      openxlsx::addStyle(wb, sheet, callout_style, rows = row, cols = 1)
    }
    row <- row + 1
  }

  invisible(row)
}


#' Create default configuration for output (internal)
#' @keywords internal
create_default_config <- function() {
  list(
    confidence_level = 0.95,
    bootstrap_iterations = 5000,
    multiple_comparison_method = "None",
    calculate_effective_n = TRUE
  )
}
