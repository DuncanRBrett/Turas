# ==============================================================================
# CONJOINT OUTPUT WRITER - ENHANCED
# ==============================================================================
#
# Module: Conjoint Analysis - Excel Output
# Purpose: Create formatted Excel workbook with comprehensive results
# Version: 2.1.0 (8-Sheet Specification - Phase 2)
# Date: 2025-12-12
#
# Output Structure (8 sheets per specification):
#   1. Market Simulator    - Interactive what-if analysis tool
#   2. Attribute Importance - Ranked importance scores
#   3. Part-Worth Utilities - Zero-centered utilities by level
#   4. Utility Chart Data   - Pre-formatted data for Excel charts
#   5. Model Fit           - Diagnostic statistics and quality metrics
#   6. Configuration       - Study design summary
#   7. Raw Coefficients    - Uncentered model coefficients with std errors
#   8. Data Summary        - Response counts, completion rates
#
# ==============================================================================

#' Write Conjoint Results to Excel
#'
#' Creates formatted Excel workbook with 8-sheet structure per specification
#'
#' @param utilities Utilities data frame
#' @param importance Importance data frame
#' @param diagnostics Diagnostics list
#' @param model_result Model estimation results
#' @param config Configuration
#' @param data_info Data information list
#' @param output_file Output file path
#' @param run_result TRS run result (optional, for Run_Status sheet)
#' @keywords internal
write_conjoint_output <- function(utilities, importance, diagnostics, model_result,
                                  config, data_info, output_file, run_result = NULL) {

  wb <- openxlsx::createWorkbook()

  # Create styles
  header_style <- create_header_style()
  title_style <- create_title_style()
  positive_style <- create_positive_style()
  negative_style <- create_negative_style()

  # Sheet 1: Market Simulator (ALWAYS generated - primary deliverable)
  create_market_simulator_sheet(wb, utilities, importance, config, header_style)
  create_simulator_data_sheet(wb, utilities, importance, header_style)

  # Sheet 2: Attribute Importance
  create_importance_sheet(wb, importance, header_style, positive_style)

  # Sheet 3: Part-Worth Utilities
  create_utilities_sheet(wb, utilities, header_style, positive_style, negative_style)

  # Sheet 4: Utility Chart Data
  create_utility_chart_data_sheet(wb, utilities, importance, header_style)

  # Sheet 5: Model Fit
  create_model_fit_sheet(wb, diagnostics, model_result, header_style)

  # Sheet 6: Configuration
  create_configuration_sheet(wb, config, header_style)

  # Sheet 7: Raw Coefficients
  create_raw_coefficients_sheet(wb, model_result, header_style)

  # Sheet 8: Data Summary
  create_data_summary_sheet(wb, data_info, config, header_style)

  # Sheet 9: TRS Run_Status (if run_result provided)
  if (!is.null(run_result)) {
    tryCatch({
      if (!exists("turas_write_run_status_sheet", mode = "function")) {
        # Try to source the writer
        possible_paths <- c(
          file.path(getwd(), "modules", "shared", "lib", "trs_run_status_writer.R"),
          file.path(dirname(getwd()), "shared", "lib", "trs_run_status_writer.R")
        )
        for (p in possible_paths) {
          if (file.exists(p)) {
            source(p)
            break
          }
        }
      }
      if (exists("turas_write_run_status_sheet", mode = "function")) {
        turas_write_run_status_sheet(wb, run_result)
      }
    }, error = function(e) {
      message(sprintf("[TRS INFO] CONJ_RUN_STATUS_WRITE_FAILED: Could not write Run_Status sheet: %s", e$message))
    })
  }

  # Save workbook (TRS v1.0: Use atomic save if available)
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_file, run_result = run_result, module = "CONJ")
    if (!save_result$success) {
      conjoint_refuse(
        code = "IO_OUTPUT_SAVE_FAILED",
        title = "Failed to Save Excel Output",
        problem = sprintf("Failed to save Excel file: %s", save_result$error),
        why_it_matters = "Results cannot be delivered if the output file cannot be saved.",
        how_to_fix = c(
          "Check that the file is not open in Excel",
          "Verify the directory is writable",
          "Ensure sufficient disk space is available"
        ),
        details = sprintf("Attempted path: %s", output_file)
      )
    }
  } else {
    # Fallback to direct save
    tryCatch({
      openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
    }, error = function(e) {
      conjoint_refuse(
        code = "IO_OUTPUT_SAVE_FAILED_DIRECT",
        title = "Failed to Save Excel Output",
        problem = sprintf("Failed to save Excel file: %s", conditionMessage(e)),
        why_it_matters = "Results cannot be delivered if the output file cannot be saved.",
        how_to_fix = c(
          "Check that the file is not open in Excel",
          "Verify the directory is writable",
          "Ensure sufficient disk space is available"
        ),
        details = sprintf("Attempted path: %s", output_file)
      )
    })
  }
}


# ==============================================================================
# NEW SHEET FUNCTIONS FOR 8-SHEET SPECIFICATION
# ==============================================================================

#' Create Utility Chart Data Sheet
#'
#' Pre-formatted data for easy Excel charting
#'
#' @keywords internal
create_utility_chart_data_sheet <- function(wb, utilities, importance, header_style) {

  openxlsx::addWorksheet(wb, "Utility Chart Data", tabColour = "#9DC3E6")
  row <- 1

  # Section 1: Importance Chart Data
  openxlsx::writeData(wb, "Utility Chart Data", "ATTRIBUTE IMPORTANCE (for bar chart)",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Utility Chart Data", header_style, rows = row, cols = 1:2)
  row <- row + 1

  # Sort by importance
  imp_sorted <- importance[order(-importance$Importance), ]
  imp_chart <- data.frame(
    Attribute = imp_sorted$Attribute,
    Importance = imp_sorted$Importance,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Utility Chart Data", imp_chart, startRow = row, startCol = 1,
                     headerStyle = header_style)
  row <- row + nrow(imp_chart) + 3

  # Section 2: Utilities by Attribute (for grouped bar charts)
  openxlsx::writeData(wb, "Utility Chart Data", "UTILITIES BY ATTRIBUTE (for grouped bar charts)",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Utility Chart Data", header_style, rows = row, cols = 1:3)
  row <- row + 1

  # Create wide format for each attribute
  for (attr in unique(utilities$Attribute)) {
    attr_utils <- utilities[utilities$Attribute == attr, c("Level", "Utility")]
    attr_utils <- attr_utils[order(-attr_utils$Utility), ]

    openxlsx::writeData(wb, "Utility Chart Data", attr, startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Utility Chart Data",
                      openxlsx::createStyle(textDecoration = "bold"),
                      rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, "Utility Chart Data", attr_utils, startRow = row, startCol = 1,
                       headerStyle = header_style)
    row <- row + nrow(attr_utils) + 2
  }

  # Section 3: All utilities in long format (for pivot charts)
  openxlsx::writeData(wb, "Utility Chart Data", "ALL UTILITIES - LONG FORMAT (for pivot charts)",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Utility Chart Data", header_style, rows = row, cols = 1:3)
  row <- row + 1

  chart_data <- utilities[, c("Attribute", "Level", "Utility")]
  openxlsx::writeData(wb, "Utility Chart Data", chart_data, startRow = row, startCol = 1,
                     headerStyle = header_style)

  # Apply number formatting
  num_style <- openxlsx::createStyle(numFmt = "0.000")
  openxlsx::addStyle(wb, "Utility Chart Data", num_style,
                    rows = (row + 1):(row + nrow(chart_data)),
                    cols = 3, gridExpand = TRUE)

  # Set column widths
  openxlsx::setColWidths(wb, "Utility Chart Data", cols = 1:3, widths = c(20, 20, 15))

  # Freeze top row
  openxlsx::freezePane(wb, "Utility Chart Data", firstRow = TRUE)
}


#' Create Model Fit Sheet (replaces Model Diagnostics)
#'
#' Comprehensive fit statistics and quality metrics
#'
#' @keywords internal
create_model_fit_sheet <- function(wb, diagnostics, model_result, header_style) {

  openxlsx::addWorksheet(wb, "Model Fit", tabColour = "#70AD47")
  row <- 1

  # Section 1: Model Fit Statistics
  openxlsx::writeData(wb, "Model Fit", "MODEL FIT STATISTICS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Model Fit", header_style, rows = row, cols = 1:2)
  row <- row + 1

  if (!is.null(diagnostics$fit_statistics)) {
    fit_stats <- data.frame(
      Metric = c("McFadden R²", "Hit Rate", "Log-Likelihood", "AIC", "BIC"),
      Value = c(
        sprintf("%.4f", diagnostics$fit_statistics$mcfadden_r2 %||% NA),
        sprintf("%.1f%%", (diagnostics$fit_statistics$hit_rate %||% 0) * 100),
        sprintf("%.2f", diagnostics$fit_statistics$log_likelihood %||% NA),
        sprintf("%.2f", diagnostics$fit_statistics$aic %||% NA),
        sprintf("%.2f", diagnostics$fit_statistics$bic %||% NA)
      ),
      Interpretation = c(
        "0.2-0.4 is considered good for choice models",
        "% correctly predicted choices (random = 33% for 3 alternatives)",
        "Higher (less negative) is better",
        "Lower is better (penalizes complexity)",
        "Lower is better (stronger complexity penalty)"
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Model Fit", fit_stats, startRow = row, startCol = 1,
                       headerStyle = header_style)
    row <- row + nrow(fit_stats) + 2
  }

  # Section 2: Sample Information
  openxlsx::writeData(wb, "Model Fit", "SAMPLE INFORMATION",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Model Fit", header_style, rows = row, cols = 1:2)
  row <- row + 1

  sample_info <- data.frame(
    Metric = c("Total Observations", "Estimation Method", "Converged"),
    Value = c(
      as.character(model_result$n_obs %||% "N/A"),
      model_result$method %||% "N/A",
      if (!is.null(model_result$convergence$converged))
        ifelse(model_result$convergence$converged, "Yes", "No") else "N/A"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Model Fit", sample_info, startRow = row, startCol = 1,
                     headerStyle = header_style)
  row <- row + nrow(sample_info) + 2

  # Section 3: Quality Assessment
  if (!is.null(diagnostics$quality_assessment)) {
    openxlsx::writeData(wb, "Model Fit", "QUALITY ASSESSMENT",
                       startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Model Fit", header_style, rows = row, cols = 1:2)
    row <- row + 1

    qa <- diagnostics$quality_assessment
    quality_df <- data.frame(
      Item = c("Quality Level", "Recommendation"),
      Value = c(qa$level %||% "N/A", qa$recommendation %||% "N/A"),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Model Fit", quality_df, startRow = row, startCol = 1,
                       headerStyle = header_style)
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Model Fit", cols = 1:3, widths = c(25, 20, 50))
}


#' Create Raw Coefficients Sheet
#'
#' Uncentered model coefficients with standard errors
#'
#' @keywords internal
create_raw_coefficients_sheet <- function(wb, model_result, header_style) {

  openxlsx::addWorksheet(wb, "Raw Coefficients", tabColour = "#BF8F00")
  row <- 1

  # Title
  openxlsx::writeData(wb, "Raw Coefficients", "RAW MODEL COEFFICIENTS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Raw Coefficients", header_style, rows = row, cols = 1:5)
  row <- row + 2

  # Build coefficients table
  coefs <- model_result$coefficients
  std_errors <- model_result$std_errors

  if (!is.null(coefs) && length(coefs) > 0) {
    # Calculate z-values and p-values
    z_values <- coefs / std_errors
    p_values <- 2 * (1 - pnorm(abs(z_values)))

    # Create data frame
    coef_df <- data.frame(
      Coefficient = names(coefs),
      Estimate = coefs,
      Std_Error = std_errors,
      z_value = z_values,
      p_value = p_values,
      Significance = ifelse(p_values < 0.001, "***",
                     ifelse(p_values < 0.01, "**",
                     ifelse(p_values < 0.05, "*",
                     ifelse(p_values < 0.1, ".", "")))),
      stringsAsFactors = FALSE,
      row.names = NULL
    )

    # Write data
    openxlsx::writeData(wb, "Raw Coefficients", coef_df, startRow = row, startCol = 1,
                       headerStyle = header_style)

    # Apply number formatting
    num_style <- openxlsx::createStyle(numFmt = "0.0000")
    openxlsx::addStyle(wb, "Raw Coefficients", num_style,
                      rows = (row + 1):(row + nrow(coef_df)),
                      cols = 2:5, gridExpand = TRUE)

    row <- row + nrow(coef_df) + 2
  } else {
    openxlsx::writeData(wb, "Raw Coefficients", "No coefficients available",
                       startRow = row, startCol = 1)
    row <- row + 2
  }

  # Add legend
  openxlsx::writeData(wb, "Raw Coefficients", "Significance codes:",
                     startRow = row, startCol = 1)
  row <- row + 1
  openxlsx::writeData(wb, "Raw Coefficients",
                     "*** p < 0.001, ** p < 0.01, * p < 0.05, . p < 0.1",
                     startRow = row, startCol = 1)

  # Add note about zero-centering
  row <- row + 2
  openxlsx::writeData(wb, "Raw Coefficients",
                     "NOTE: These are uncentered coefficients from the model.",
                     startRow = row, startCol = 1)
  row <- row + 1
  openxlsx::writeData(wb, "Raw Coefficients",
                     "See 'Part-Worth Utilities' sheet for zero-centered utilities.",
                     startRow = row, startCol = 1)

  note_style <- openxlsx::createStyle(fontColour = "#666666", textDecoration = "italic")
  openxlsx::addStyle(wb, "Raw Coefficients", note_style, rows = (row-1):row, cols = 1)

  # Set column widths
  openxlsx::setColWidths(wb, "Raw Coefficients", cols = 1:6, widths = c(30, 12, 12, 10, 12, 12))

  # Freeze top row
  openxlsx::freezePane(wb, "Raw Coefficients", firstRow = TRUE)
}


#' Create Importance Sheet
#' @keywords internal
create_importance_sheet <- function(wb, importance, header_style, positive_style) {

  openxlsx::addWorksheet(wb, "Attribute Importance")

  # Write data
  openxlsx::writeData(wb, "Attribute Importance", importance, startRow = 1)

  # Apply styles
  openxlsx::addStyle(wb, "Attribute Importance", header_style, rows = 1,
                    cols = 1:ncol(importance), gridExpand = TRUE)

  # Set column widths
  openxlsx::setColWidths(wb, "Attribute Importance", cols = 1:ncol(importance),
                        widths = "auto")

  # Freeze top row
  openxlsx::freezePane(wb, "Attribute Importance", firstRow = TRUE)
}


#' Create Utilities Sheet
#' @keywords internal
create_utilities_sheet <- function(wb, utilities, header_style,
                                  positive_style, negative_style) {

  openxlsx::addWorksheet(wb, "Part-Worth Utilities")

  # Write data
  openxlsx::writeData(wb, "Part-Worth Utilities", utilities, startRow = 1)

  # Apply header style
  openxlsx::addStyle(wb, "Part-Worth Utilities", header_style, rows = 1,
                    cols = 1:ncol(utilities), gridExpand = TRUE)

  # Apply conditional formatting to utilities column
  utility_col <- which(names(utilities) == "Utility")
  if (length(utility_col) > 0) {
    # Positive utilities
    for (i in 2:nrow(utilities)+1) {
      if (utilities$Utility[i-1] > 0) {
        openxlsx::addStyle(wb, "Part-Worth Utilities", positive_style,
                          rows = i, cols = utility_col)
      } else if (utilities$Utility[i-1] < 0) {
        openxlsx::addStyle(wb, "Part-Worth Utilities", negative_style,
                          rows = i, cols = utility_col)
      }
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Part-Worth Utilities", cols = 1:ncol(utilities),
                        widths = "auto")

  # Freeze top row
  openxlsx::freezePane(wb, "Part-Worth Utilities", firstRow = TRUE)
}


# NOTE: create_diagnostics_sheet removed in v2.1.0, replaced by create_model_fit_sheet


#' Create Data Summary Sheet
#' @keywords internal
create_data_summary_sheet <- function(wb, data_info, config, header_style) {

  openxlsx::addWorksheet(wb, "Data Summary")
  row <- 1

  # Sample statistics
  openxlsx::writeData(wb, "Data Summary", "SAMPLE STATISTICS",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Data Summary", header_style, rows = row, cols = 1:2)
  row <- row + 1

  sample_stats <- data.frame(
    Metric = c("Respondents", "Choice Sets", "Total Observations",
               "Has None Option"),
    Value = c(
      data_info$n_respondents,
      data_info$n_choice_sets,
      data_info$n_profiles,
      data_info$has_none
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Data Summary", sample_stats,
                     startRow = row, startCol = 1)
  row <- row + nrow(sample_stats) + 2

  # Validation summary
  if (!is.null(data_info$validation)) {
    openxlsx::writeData(wb, "Data Summary", "VALIDATION SUMMARY",
                       startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Data Summary", header_style, rows = row, cols = 1:2)
    row <- row + 1

    val_summary <- data.frame(
      Item = c("Critical Errors", "Warnings", "Info Messages"),
      Count = c(
        length(data_info$validation$errors),
        length(data_info$validation$warnings),
        length(data_info$validation$info)
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Data Summary", val_summary,
                       startRow = row, startCol = 1)
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Data Summary", cols = 1:2, widths = "auto")
}


#' Create Configuration Sheet
#' @keywords internal
create_configuration_sheet <- function(wb, config, header_style) {

  openxlsx::addWorksheet(wb, "Configuration")

  config_summary <- data.frame(
    Attribute = config$attributes$AttributeName,
    NumLevels = config$attributes$NumLevels,
    Levels = config$attributes$LevelNames,
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Configuration", config_summary, startRow = 1)
  openxlsx::addStyle(wb, "Configuration", header_style, rows = 1,
                    cols = 1:ncol(config_summary), gridExpand = TRUE)

  openxlsx::setColWidths(wb, "Configuration", cols = 1:ncol(config_summary),
                        widths = "auto")

  # Freeze top row
  openxlsx::freezePane(wb, "Configuration", firstRow = TRUE)
}
