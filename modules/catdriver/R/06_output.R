# ==============================================================================
# CATEGORICAL KEY DRIVER - OUTPUT GENERATION
# ==============================================================================
#
# Core output generation: workbook creation and styles.
#
# Related modules:
#   - 06a_sheets_summary.R: Executive summary and importance sheets
#   - 06b_sheets_detail.R: Model summary, odds ratios, diagnostics
#
# Version: 2.0
# Date: December 2024
#
# ==============================================================================

#' Generate Excel Output
#'
#' Creates a formatted Excel workbook with all analysis results.
#'
#' @param results Full analysis results list
#' @param config Configuration list
#' @param output_file Path to output Excel file
#' @return Path to created file (invisibly)
#' @export
write_catdriver_output <- function(results, config, output_file) {

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Define styles
  styles <- create_output_styles(wb)

  # Sheet 1: Executive Summary
  add_executive_summary_sheet(wb, results, config, styles)

  # Sheet 2: Importance Summary
  add_importance_sheet(wb, results, config, styles)

  # Sheet 3: Factor Patterns
  add_patterns_sheet(wb, results, config, styles)

  # Sheet 4: Model Summary
  add_model_summary_sheet(wb, results, config, styles)

  # Sheet 5: Odds Ratios (if detailed output)
  if (config$detailed_output) {
    add_odds_ratios_sheet(wb, results, config, styles)
  }

  # Sheet 6: Diagnostics (if detailed output)
  if (config$detailed_output) {
    add_diagnostics_sheet(wb, results, config, styles)
  }

  # Save workbook
  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)

  invisible(output_file)
}


#' Create Output Styles
#'
#' @param wb Workbook object
#' @return List of style objects
#' @keywords internal
create_output_styles <- function(wb) {

  list(
    # Header style - blue background
    header = openxlsx::createStyle(
      fontColour = "#FFFFFF",
      fgFill = "#4472C4",
      halign = "center",
      valign = "center",
      textDecoration = "bold",
      border = "TopBottomLeftRight",
      borderColour = "#2F5496"
    ),

    # Sub-header style
    subheader = openxlsx::createStyle(
      fgFill = "#D6DCE4",
      halign = "left",
      textDecoration = "bold",
      border = "TopBottomLeftRight"
    ),

    # Title style
    title = openxlsx::createStyle(
      fontSize = 16,
      textDecoration = "bold",
      halign = "left"
    ),

    # Section title
    section = openxlsx::createStyle(
      fontSize = 12,
      textDecoration = "bold",
      halign = "left",
      border = "bottom",
      borderColour = "#4472C4"
    ),

    # Normal text
    normal = openxlsx::createStyle(
      halign = "left",
      valign = "center"
    ),

    # Number format
    number = openxlsx::createStyle(
      halign = "right",
      numFmt = "0.00"
    ),

    # Percentage format
    pct = openxlsx::createStyle(
      halign = "right",
      numFmt = "0.0%"
    ),

    # Integer format
    integer = openxlsx::createStyle(
      halign = "right",
      numFmt = "0"
    ),

    # Reference row (gray background)
    reference = openxlsx::createStyle(
      fgFill = "#E2EFDA",
      halign = "left"
    ),

    # Warning style
    warning = openxlsx::createStyle(
      fgFill = "#FFF2CC",
      halign = "left"
    ),

    # Success style
    success = openxlsx::createStyle(
      fgFill = "#C6EFCE",
      halign = "left"
    ),

    # Error style
    error = openxlsx::createStyle(
      fgFill = "#FFC7CE",
      halign = "left"
    )
  )
}


#' Print Console Summary
#'
#' Prints a summary of results to console.
#'
#' @param results Analysis results
#' @param config Configuration
#' @export
print_console_summary <- function(results, config) {

  summary_lines <- generate_executive_summary(results, config)

  cat("\n")
  for (line in summary_lines) {
    cat(line, "\n")
  }
  cat("\n")
}
