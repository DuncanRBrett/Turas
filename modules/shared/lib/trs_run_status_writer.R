# ==============================================================================
# TURAS RUN STATUS SHEET WRITER (TRS v1.0)
# ==============================================================================
#
# Writes a standardized Run_Status sheet to Excel workbooks.
# This sheet documents the TRS execution state and any events that occurred.
#
# USAGE:
#   # At end of module, before saving workbook:
#   rr <- turas_run_state_result(state)
#   turas_write_run_status_sheet(wb, rr)
#   openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================


#' Write TRS Run Status Sheet to Workbook
#'
#' Adds a Run_Status sheet to an openxlsx workbook documenting the
#' execution state and any INFO/PARTIAL events that occurred.
#'
#' @param wb openxlsx workbook object
#' @param run_result List. Result from turas_run_state_result()
#' @param sheet Character. Sheet name (default "Run_Status")
#' @return TRUE invisibly
#' @export
turas_write_run_status_sheet <- function(wb, run_result, sheet = "Run_Status") {

  stopifnot(is.list(run_result))
  stopifnot(!is.null(run_result$status))
  stopifnot(!is.null(run_result$events))

  # Ensure openxlsx is available
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    message("[TRS WARNING] openxlsx not available - Run_Status sheet not written")
    return(invisible(FALSE))
  }

  # Remove existing sheet if present
  if (sheet %in% names(wb)) {
    openxlsx::removeWorksheet(wb, sheet)
  }

  openxlsx::addWorksheet(wb, sheet)

  # ===========================================================================
  # HEADER SECTION
  # ===========================================================================

  row <- 1

  # Title
  openxlsx::writeData(wb, sheet, "TURAS RUN STATUS", startRow = row, startCol = 1)

  # Style the title
  title_style <- openxlsx::createStyle(
    fontSize = 14,
    textDecoration = "bold"
  )
  openxlsx::addStyle(wb, sheet, title_style, rows = row, cols = 1)

  row <- row + 2

  # ===========================================================================
  # SUMMARY SECTION
  # ===========================================================================

  # Determine status display color
  status_color <- switch(run_result$status,
    "PASS" = "#28A745",      # Green
    "PARTIAL" = "#FFC107",   # Amber
    "REFUSE" = "#DC3545",    # Red
    "#6C757D"                # Grey (unknown)
  )

  summary_df <- data.frame(
    Field = c("Module", "Status", "Event Count", "Duration"),
    Value = c(
      run_result$module %||% "UNKNOWN",
      run_result$status %||% "UNKNOWN",
      length(run_result$events),
      if (!is.null(run_result$duration_seconds)) {
        sprintf("%.1f seconds", run_result$duration_seconds)
      } else {
        "N/A"
      }
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, sheet, summary_df, startRow = row, startCol = 1)

  # Style status cell based on value
  status_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF",
    fgFill = status_color,
    textDecoration = "bold"
  )
  openxlsx::addStyle(wb, sheet, status_style, rows = row + 1, cols = 2)

  row <- row + nrow(summary_df) + 2

  # ===========================================================================
  # EVENTS SECTION
  # ===========================================================================

  if (length(run_result$events) > 0) {

    openxlsx::writeData(wb, sheet, "EVENTS", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet, title_style, rows = row, cols = 1)

    row <- row + 1

    # Flatten events to data frame
    events_df <- do.call(rbind, lapply(run_result$events, function(e) {
      data.frame(
        Level = e$level %||% NA_character_,
        Code = e$code %||% NA_character_,
        Title = e$title %||% NA_character_,
        Module = e$module %||% NA_character_,
        Question_Code = e$question_code %||% NA_character_,
        Section = e$section %||% NA_character_,
        Stage = e$stage %||% NA_character_,
        Detail = e$detail %||% NA_character_,
        Problem = e$problem %||% NA_character_,
        Fix = e$fix %||% NA_character_,
        Error = e$error %||% NA_character_,
        stringsAsFactors = FALSE
      )
    }))

    openxlsx::writeData(
      wb, sheet, events_df,
      startRow = row, startCol = 1,
      withFilter = TRUE,
      headerStyle = openxlsx::createStyle(
        textDecoration = "bold",
        fgFill = "#E9ECEF",
        border = "TopBottom"
      )
    )

    # Style Level column based on value
    for (i in seq_len(nrow(events_df))) {
      level <- events_df$Level[i]
      level_color <- switch(level,
        "INFO" = "#17A2B8",     # Blue
        "PARTIAL" = "#FFC107",  # Amber
        "#6C757D"               # Grey
      )
      level_style <- openxlsx::createStyle(
        fontColour = "#FFFFFF",
        fgFill = level_color
      )
      openxlsx::addStyle(wb, sheet, level_style, rows = row + i, cols = 1)
    }

    # Set column widths
    openxlsx::setColWidths(wb, sheet, cols = 1:ncol(events_df),
                           widths = c(10, 30, 40, 15, 15, 15, 15, 50, 50, 50, 50))

  } else {
    # No events - all good
    openxlsx::writeData(wb, sheet, "No events recorded - analysis completed cleanly.",
                        startRow = row, startCol = 1)
  }

  # ===========================================================================
  # TIMESTAMP FOOTER
  # ===========================================================================

  row <- row + max(length(run_result$events) + 3, 3)

  timestamp_text <- sprintf("Generated: %s",
                            format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  openxlsx::writeData(wb, sheet, timestamp_text, startRow = row, startCol = 1)

  footer_style <- openxlsx::createStyle(
    fontSize = 9,
    fontColour = "#6C757D"
  )
  openxlsx::addStyle(wb, sheet, footer_style, rows = row, cols = 1)

  invisible(TRUE)
}


#' Null coalesce operator (if not already defined)
#' @keywords internal
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}
