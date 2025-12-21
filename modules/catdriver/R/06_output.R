# ==============================================================================
# CATEGORICAL KEY DRIVER - OUTPUT GENERATION
# ==============================================================================
#
# Core output generation: workbook creation and styles.
# TRS v1.0: Includes Run_Status sheet per hardening spec.
#
# Related modules:
#   - 06a_sheets_summary.R: Executive summary and importance sheets
#   - 06b_sheets_detail.R: Model summary, odds ratios, diagnostics
#
# Version: 1.1 (TRS Hardening)
# Date: December 2024
#
# ==============================================================================

#' Generate Excel Output
#'
#' Creates a formatted Excel workbook with all analysis results.
#' TRS v1.0: Includes Run_Status sheet with status, degraded flag, and reasons.
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

  # TRS v1.0: Sheet 1 - Run_Status (required per spec)
  add_run_status_sheet(wb, results, styles)

  # Sheet 2: Executive Summary
  add_executive_summary_sheet(wb, results, config, styles)

  # Sheet 3: Importance Summary
  add_importance_sheet(wb, results, config, styles)

  # Sheet 4: Factor Patterns
  add_patterns_sheet(wb, results, config, styles)

  # Sheet 5: Model Summary
  add_model_summary_sheet(wb, results, config, styles)

  # Sheet 6: Odds Ratios (if detailed output)
  if (config$detailed_output) {
    add_odds_ratios_sheet(wb, results, config, styles)
  }

  # Sheet 7: Diagnostics (if detailed output)
  if (config$detailed_output) {
    add_diagnostics_sheet(wb, results, config, styles)
  }

  # Save workbook (TRS v1.0: Use atomic save if available)
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_file, module = "CATD")
    if (!save_result$success) {
      stop(sprintf("Failed to save Excel file: %s\nPath: %s", save_result$error, output_file), call. = FALSE)
    }
  } else {
    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  }

  invisible(output_file)
}


#' Add Run_Status Sheet (TRS v1.0)
#'
#' Creates the required Run_Status sheet per TRS v1.0 spec.
#'
#' @param wb Workbook
#' @param results Analysis results
#' @param styles Style list
#' @keywords internal
add_run_status_sheet <- function(wb, results, styles) {

  openxlsx::addWorksheet(wb, "Run_Status")

  # Build status data
  run_status <- if (!is.null(results$run_status)) results$run_status else "PASS"
  degraded <- if (!is.null(results$degraded)) results$degraded else FALSE
  degraded_reasons <- if (!is.null(results$degraded_reasons)) results$degraded_reasons else character(0)
  affected_outputs <- if (!is.null(results$affected_outputs)) results$affected_outputs else character(0)

  # Write header
  row <- 1
  openxlsx::writeData(wb, "Run_Status", "CATDRIVER RUN STATUS", startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Run_Status", styles$title, rows = row, cols = 1)
  row <- row + 2

  # Status row
  openxlsx::writeData(wb, "Run_Status", "run_status:", startRow = row, startCol = 1)
  openxlsx::writeData(wb, "Run_Status", run_status, startRow = row, startCol = 2)
  if (run_status == "PASS") {
    openxlsx::addStyle(wb, "Run_Status", styles$success, rows = row, cols = 2)
  } else if (run_status == "PARTIAL") {
    openxlsx::addStyle(wb, "Run_Status", styles$warning, rows = row, cols = 2)
  }
  row <- row + 1

  # Degraded flag
  openxlsx::writeData(wb, "Run_Status", "degraded:", startRow = row, startCol = 1)
  openxlsx::writeData(wb, "Run_Status", if (degraded) "TRUE" else "FALSE", startRow = row, startCol = 2)
  row <- row + 1

  # Module
  openxlsx::writeData(wb, "Run_Status", "module:", startRow = row, startCol = 1)
  openxlsx::writeData(wb, "Run_Status", "CATDRIVER v1.1", startRow = row, startCol = 2)
  row <- row + 1

  # Timestamp
  openxlsx::writeData(wb, "Run_Status", "timestamp:", startRow = row, startCol = 1)
  openxlsx::writeData(wb, "Run_Status", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), startRow = row, startCol = 2)
  row <- row + 2

  # Degraded reasons (if any)
  if (length(degraded_reasons) > 0) {
    openxlsx::writeData(wb, "Run_Status", "DEGRADED REASONS:", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Run_Status", styles$section, rows = row, cols = 1)
    row <- row + 1

    for (reason in degraded_reasons) {
      openxlsx::writeData(wb, "Run_Status", paste0("- ", reason), startRow = row, startCol = 1)
      row <- row + 1
    }
    row <- row + 1
  }

  # Affected outputs (if any)
  if (length(affected_outputs) > 0) {
    openxlsx::writeData(wb, "Run_Status", "AFFECTED OUTPUTS:", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Run_Status", styles$section, rows = row, cols = 1)
    row <- row + 1

    for (output in affected_outputs) {
      openxlsx::writeData(wb, "Run_Status", paste0("- ", output), startRow = row, startCol = 1)
      row <- row + 1
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Run_Status", cols = 1, widths = 25)
  openxlsx::setColWidths(wb, "Run_Status", cols = 2, widths = 60)
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
