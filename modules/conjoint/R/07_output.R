# ==============================================================================
# CONJOINT OUTPUT WRITER - ENHANCED
# ==============================================================================
#
# Module: Conjoint Analysis - Excel Output
# Purpose: Create formatted Excel workbook with comprehensive results
# Version: 2.0.0 (Enhanced Implementation)
# Date: 2025-11-26
#
# ==============================================================================

#' Write Conjoint Results to Excel
#'
#' Creates formatted Excel workbook with enhanced conjoint analysis results
#'
#' @param utilities Utilities data frame
#' @param importance Importance data frame
#' @param diagnostics Diagnostics list
#' @param model_result Model estimation results
#' @param config Configuration
#' @param data_info Data information list
#' @param output_file Output file path
#' @keywords internal
write_conjoint_output <- function(utilities, importance, diagnostics, model_result,
                                  config, data_info, output_file) {

  wb <- openxlsx::createWorkbook()

  # Create styles
  header_style <- create_header_style()
  title_style <- create_title_style()
  positive_style <- create_positive_style()
  negative_style <- create_negative_style()

  # Sheet 1: Executive Summary
  create_executive_summary_sheet(wb, utilities, importance, diagnostics,
                                 model_result, config, data_info,
                                 header_style, title_style)

  # Sheet 2: Attribute Importance
  create_importance_sheet(wb, importance, header_style, positive_style)

  # Sheet 3: Part-Worth Utilities
  create_utilities_sheet(wb, utilities, header_style, positive_style, negative_style)

  # Sheet 4: Model Diagnostics
  create_diagnostics_sheet(wb, diagnostics, model_result, header_style)

  # Sheet 5: Market Simulator (if enabled)
  if (!is.null(config$generate_market_simulator) &&
      safe_logical(config$generate_market_simulator, default = FALSE)) {
    create_market_simulator_sheet(wb, utilities, importance, config, header_style)
    create_simulator_data_sheet(wb, utilities, importance, header_style)
  }

  # Sheet 6: Data Summary
  create_data_summary_sheet(wb, data_info, config, header_style)

  # Sheet 7: Configuration
  create_configuration_sheet(wb, config, header_style)

  # Save workbook
  tryCatch({
    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  }, error = function(e) {
    stop(create_error(
      "OUTPUT",
      sprintf("Failed to save Excel file: %s", conditionMessage(e)),
      "Check that the file is not open in Excel and the directory is writable",
      sprintf("Attempted path: %s", output_file)
    ), call. = FALSE)
  })
}


#' Create Executive Summary Sheet
#' @keywords internal
create_executive_summary_sheet <- function(wb, utilities, importance, diagnostics,
                                          model_result, config, data_info,
                                          header_style, title_style) {

  openxlsx::addWorksheet(wb, "Executive Summary")
  row <- 1

  # Title
  openxlsx::writeData(wb, "Executive Summary", "CONJOINT ANALYSIS - EXECUTIVE SUMMARY",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Executive Summary", title_style, rows = row, cols = 1)
  row <- row + 2

  # Study Information
  openxlsx::writeData(wb, "Executive Summary", "STUDY INFORMATION",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Executive Summary", header_style, rows = row, cols = 1)
  row <- row + 1

  study_info <- data.frame(
    Item = c("Analysis Type", "Estimation Method", "Sample Size",
             "Choice Sets", "Total Observations"),
    Value = c(
      config$analysis_type,
      model_result$method,
      data_info$n_respondents,
      data_info$n_choice_sets,
      model_result$n_obs
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Executive Summary", study_info, startRow = row, startCol = 1)
  row <- row + nrow(study_info) + 2

  # Top 3 Attributes
  openxlsx::writeData(wb, "Executive Summary", "TOP 3 MOST IMPORTANT ATTRIBUTES",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Executive Summary", header_style, rows = row, cols = 1)
  row <- row + 1

  top_attrs <- head(importance, 3)
  top_attrs_display <- data.frame(
    Rank = 1:nrow(top_attrs),
    Attribute = top_attrs$Attribute,
    Importance = sprintf("%.1f%%", top_attrs$Importance),
    Interpretation = top_attrs$Interpretation,
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Executive Summary", top_attrs_display,
                     startRow = row, startCol = 1)
  row <- row + nrow(top_attrs_display) + 2

  # Model Fit (if choice-based)
  if (model_result$method %in% c("mlogit", "clogit")) {
    openxlsx::writeData(wb, "Executive Summary", "MODEL FIT",
                       startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Executive Summary", header_style, rows = row, cols = 1)
    row <- row + 1

    fit_summary <- data.frame(
      Metric = c("McFadden R²", "Hit Rate", "Quality"),
      Value = c(
        sprintf("%.3f", diagnostics$fit_statistics$mcfadden_r2),
        sprintf("%.1f%%", diagnostics$fit_statistics$hit_rate * 100),
        diagnostics$quality_assessment$level
      ),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Executive Summary", fit_summary,
                       startRow = row, startCol = 1)
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Executive Summary", cols = 1:4, widths = "auto")
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


#' Create Diagnostics Sheet
#' @keywords internal
create_diagnostics_sheet <- function(wb, diagnostics, model_result, header_style) {

  openxlsx::addWorksheet(wb, "Model Diagnostics")
  row <- 1

  # Model fit statistics
  if (!is.null(diagnostics$fit_statistics)) {
    openxlsx::writeData(wb, "Model Diagnostics", "MODEL FIT STATISTICS",
                       startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Model Diagnostics", header_style, rows = row, cols = 1:2)
    row <- row + 1

    fit_stats <- data.frame(
      Metric = names(diagnostics$fit_statistics),
      Value = sapply(diagnostics$fit_statistics, function(x) {
        if (is.numeric(x)) sprintf("%.4f", x) else as.character(x)
      }),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Model Diagnostics", fit_stats,
                       startRow = row, startCol = 1)
    row <- row + nrow(fit_stats) + 2
  }

  # Convergence information
  openxlsx::writeData(wb, "Model Diagnostics", "CONVERGENCE INFORMATION",
                     startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Model Diagnostics", header_style, rows = row, cols = 1:2)
  row <- row + 1

  conv_info <- data.frame(
    Item = c("Converged", "Code", "Message"),
    Value = c(
      model_result$convergence$converged,
      model_result$convergence$code,
      model_result$convergence$message
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, "Model Diagnostics", conv_info,
                     startRow = row, startCol = 1)

  # Set column widths
  openxlsx::setColWidths(wb, "Model Diagnostics", cols = 1:2, widths = "auto")
}


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
