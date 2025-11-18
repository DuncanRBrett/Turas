# ==============================================================================
# CONJOINT OUTPUT WRITER
# ==============================================================================

#' Write Conjoint Results to Excel
#'
#' Creates formatted Excel workbook with conjoint analysis results.
#'
#' @param utilities Utilities data frame
#' @param importance Importance data frame
#' @param fit Model fit statistics
#' @param config Configuration
#' @param output_file Output file path
#' @keywords internal
write_conjoint_output <- function(utilities, importance, fit, config, output_file) {

  wb <- openxlsx::createWorkbook()

  # Sheet 1: Attribute Importance
  openxlsx::addWorksheet(wb, "Attribute Importance")
  openxlsx::writeData(wb, "Attribute Importance", importance, startRow = 1)

  # Format importance sheet
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    fontColour = "#FFFFFF",
    fgFill = "#4472C4",
    halign = "left",
    valign = "center",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  openxlsx::addStyle(wb, "Attribute Importance", header_style, rows = 1,
                     cols = 1:ncol(importance), gridExpand = TRUE)

  # Sheet 2: Part-Worth Utilities
  openxlsx::addWorksheet(wb, "Part-Worth Utilities")
  openxlsx::writeData(wb, "Part-Worth Utilities", utilities, startRow = 1)
  openxlsx::addStyle(wb, "Part-Worth Utilities", header_style, rows = 1,
                     cols = 1:ncol(utilities), gridExpand = TRUE)

  # Sheet 3: Model Fit
  openxlsx::addWorksheet(wb, "Model Fit")
  fit_df <- data.frame(
    Metric = names(fit),
    Value = unlist(fit),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Model Fit", fit_df, startRow = 1)
  openxlsx::addStyle(wb, "Model Fit", header_style, rows = 1,
                     cols = 1:2, gridExpand = TRUE)

  # Sheet 4: Configuration Summary
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

  # Set column widths
  openxlsx::setColWidths(wb, "Attribute Importance", cols = 1:ncol(importance), widths = "auto")
  openxlsx::setColWidths(wb, "Part-Worth Utilities", cols = 1:ncol(utilities), widths = "auto")
  openxlsx::setColWidths(wb, "Model Fit", cols = 1:2, widths = "auto")
  openxlsx::setColWidths(wb, "Configuration", cols = 1:ncol(config_summary), widths = "auto")

  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
}
