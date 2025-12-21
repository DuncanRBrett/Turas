# ==============================================================================
# OUTPUT GENERATOR - TURAS V10.0
# ==============================================================================
# Functions for generating Excel output with confidence analysis results
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
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
# ==============================================================================

OUTPUT_VERSION <- "10.0"

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

if (!require("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required. Install with: install.packages('openxlsx')", call. = FALSE)
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

source_if_exists("utils.R")

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
    stop("decimal_sep must be either '.' or ','", call. = FALSE)
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

  # Save workbook
  tryCatch({
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
    message(sprintf("\n[TRS INFO] Output written to: %s", output_path))
  }, error = function(e) {
    stop(sprintf(
      "Failed to save Excel file\nPath: %s\nError: %s\n\nTroubleshooting:\n  1. Check file is not open in Excel\n  2. Verify output directory exists\n  3. Check write permissions",
      output_path,
      conditionMessage(e)
    ), call. = FALSE)
  })

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
    openxlsx::writeData(wb, "Summary", "⚠ Warnings",
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
    openxlsx::writeData(wb, "Summary", "✓ No Warnings",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Summary",
                       style = openxlsx::createStyle(fontSize = 12, textDecoration = "bold",
                                                     fontColour = "#008000"),
                       rows = row, cols = 1)
  }

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
  notes <- c(
    "DEFF (Design Effect):",
    "  1.00 = No loss of precision from weighting",
    "  1.05-1.20 = Modest loss (5-20%)",
    "  1.20-2.00 = Moderate loss (20-50%)",
    "  >2.00 = Substantial loss (>50%)",
    "",
    "Weight CV (Coefficient of Variation):",
    "  <0.20 = Modest variation",
    "  0.20-0.30 = Moderate variation",
    "  >0.30 = High variation"
  )

  for (note in notes) {
    openxlsx::writeData(wb, "Study_Level", note, startCol = 1, startRow = row)
    row <- row + 1
  }

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

    # Normal approximation CI
    if (!is.null(q_result$normal_ci)) {
      base_row$Normal_Lower <- q_result$normal_ci$lower
      base_row$Normal_Upper <- q_result$normal_ci$upper
      base_row$SE <- q_result$normal_ci$se
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

  # Methodology content
  methodology_text <- c(
    "PROPORTIONS:",
    "",
    "1. Normal Approximation (Margin of Error)",
    "   Formula: MOE = z * sqrt(p*(1-p)/n)",
    "   Use: Large samples (n*p >= 10 and n*(1-p) >= 10)",
    "   Confidence Interval: [p - MOE, p + MOE]",
    "",
    "2. Wilson Score Interval",
    "   Better for extreme proportions (p < 0.1 or p > 0.9)",
    "   Automatically provides asymmetric intervals",
    "   Recommended for small samples or extreme proportions",
    "",
    "3. Bootstrap",
    "   Non-parametric resampling method (5000-10000 iterations)",
    "   No distributional assumptions required",
    "   Percentile method for confidence intervals",
    "",
    "4. Bayesian (Beta-Binomial)",
    "   Posterior: Beta(alpha + x, beta + n - x)",
    "   Uninformed prior: Beta(1,1) = Uniform(0,1)",
    "   Informed prior: Beta from previous wave data",
    "",
    "MEANS:",
    "",
    "1. t-Distribution",
    "   Formula: CI = mean ± t(df) * SE",
    "   SE = sd / sqrt(n_eff)",
    "   Accounts for design effect in weighted data",
    "",
    "2. Bootstrap",
    "   Resampling with replacement (5000-10000 iterations)",
    "   Preserves survey weights if applicable",
    "   Percentile method for confidence intervals",
    "",
    "3. Bayesian (Normal-Normal Conjugate)",
    "   Prior: N(mu0, sigma0²/n0)",
    "   Posterior: Precision-weighted combination of prior and data",
    "   Uninformed: very weak prior (large prior variance)",
    "   Informed: from previous wave statistics",
    "",
    "NET PROMOTER SCORE (NPS):",
    "",
    "Formula: NPS = %Promoters - %Detractors",
    "  Scale: -100 to +100",
    "  Promoters: High scores (typically 9-10 on 0-10 scale)",
    "  Detractors: Low scores (typically 0-6)",
    "  Passives: Middle scores (7-8, not included in NPS)",
    "",
    "1. Normal Approximation",
    "   Variance of difference formula:",
    "   Var(NPS) = Var(prom) + Var(detr)",
    "   SE = sqrt(p_prom*(1-p_prom)/n + p_detr*(1-p_detr)/n) * 100",
    "   Uses n_eff for weighted data",
    "",
    "2. Bootstrap",
    "   Resampling with replacement (5000-10000 iterations)",
    "   Preserves survey weights if applicable",
    "   Percentile method for confidence intervals",
    "",
    "3. Bayesian",
    "   Normal approximation to NPS distribution",
    "   Prior: N(mu0, sigma0²)",
    "   Posterior combines prior and data (precision-weighted)",
    "",
    "WEIGHTING:",
    "",
    "Design Effect (DEFF): DEFF = 1 + CV²",
    "  where CV = coefficient of variation of weights",
    "",
    "Effective Sample Size: n_eff = (Σw)² / Σw²",
    "  Kish (1965) approximation",
    "",
    "Standard errors use effective n for weighted data",
    "",
    "REFERENCES:",
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
    openxlsx::writeData(wb, "Warnings", "✓ No warnings detected",
                        startCol = 1, startRow = row)
    openxlsx::addStyle(wb, "Warnings",
                       style = openxlsx::createStyle(fontSize = 12, fontColour = "#008000"),
                       rows = row, cols = 1)
  } else {
    # Write warnings
    warnings_df <- data.frame(
      Number = seq_along(warnings),
      Warning = warnings,
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
                       cols = 1:2, gridExpand = TRUE)

    # Auto-size columns
    openxlsx::setColWidths(wb, "Warnings", cols = 1:2, widths = "auto")
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
