# ==============================================================================
# SEGMENT MODULE - EXCEL STYLES
# ==============================================================================
# Shared openxlsx style definitions for professional Excel output.
# All segment module Excel exports use these styles for consistent branding.
#
# Colour scheme:
#   Brand:  #323367 (Turas navy)
#   Accent: #CC9900 (warm gold)
#   Header text: white on brand background
#   Section: light grey bands
#   Data: alternating row shading
#
# Version: 11.0
# ==============================================================================


# ==============================================================================
# STYLE CONSTANTS
# ==============================================================================

SEG_BRAND_COLOUR    <- "#323367"
SEG_ACCENT_COLOUR   <- "#CC9900"
SEG_HEADER_FG       <- "#FFFFFF"
SEG_SECTION_BG      <- "#D9D9D9"
SEG_ROW_ALT_BG      <- "#F5F7FA"
SEG_GREEN_BG        <- "#E8F5E9"
SEG_AMBER_BG        <- "#FFF8E1"
SEG_RED_BG          <- "#FFEBEE"
SEG_FONT_NAME       <- "Aptos"


# ==============================================================================
# FORMULA INJECTION PROTECTION
# ==============================================================================
# Inline fallback for when shared turas_excel_escape() is not available.
# Uses vapply+substr (NOT regex — R's regex treats \n inside [] as literal).
# Matches OWASP CSV injection vector list: =, +, -, @, \t, \r, \n

seg_escape_cell <- if (exists("turas_excel_escape", mode = "function")) {
  turas_excel_escape
} else {
  function(x) {
    if (!is.character(x)) return(x)
    vapply(x, function(val) {
      if (is.na(val) || !nzchar(val)) return(val)
      first_char <- substr(val, 1, 1)
      if (first_char %in% c("=", "+", "-", "@", "\t", "\r", "\n")) {
        paste0("'", val)
      } else {
        val
      }
    }, character(1), USE.NAMES = FALSE)
  }
}

#' Escape all character columns in a data frame for Excel formula injection
#' @param df Data frame to escape
#' @return Data frame with character columns escaped
#' @keywords internal
seg_escape_df <- function(df) {
  if (!is.data.frame(df) || nrow(df) == 0) return(df)
  char_cols <- vapply(df, is.character, logical(1))
  for (col in names(df)[char_cols]) {
    df[[col]] <- seg_escape_cell(df[[col]])
  }
  # Also escape column names
  names(df) <- seg_escape_cell(names(df))
  df
}
SEG_FONT_SIZE       <- 11
SEG_FONT_SIZE_TITLE <- 14


# ==============================================================================
# STYLE CREATORS
# ==============================================================================

#' Create Segment Header Style
#'
#' Brand-coloured header row: white text on #323367 background, bold.
#'
#' @return openxlsx Style object
#' @keywords internal
seg_style_header <- function() {
  openxlsx::createStyle(
    fontName = SEG_FONT_NAME,
    fontSize = SEG_FONT_SIZE,
    fontColour = SEG_HEADER_FG,
    fgFill = SEG_BRAND_COLOUR,
    halign = "center",
    valign = "center",
    textDecoration = "bold",
    border = "bottom",
    borderColour = SEG_BRAND_COLOUR,
    wrapText = TRUE
  )
}


#' Create Segment Section Header Style
#'
#' Light grey band for grouping sections.
#'
#' @return openxlsx Style object
#' @keywords internal
seg_style_section <- function() {
  openxlsx::createStyle(
    fontName = SEG_FONT_NAME,
    fontSize = SEG_FONT_SIZE,
    fgFill = SEG_SECTION_BG,
    textDecoration = "bold",
    border = "TopBottom",
    borderColour = "#BDBDBD"
  )
}


#' Create Segment Data Style (Normal)
#'
#' @param alt Logical, use alternating row background
#' @return openxlsx Style object
#' @keywords internal
seg_style_data <- function(alt = FALSE) {
  openxlsx::createStyle(
    fontName = SEG_FONT_NAME,
    fontSize = SEG_FONT_SIZE,
    fgFill = if (alt) SEG_ROW_ALT_BG else "#FFFFFF",
    halign = "center",
    valign = "center"
  )
}


#' Create Segment Number Style
#'
#' @param decimal_places Integer, number of decimal places
#' @param alt Logical, use alternating row background
#' @return openxlsx Style object
#' @keywords internal
seg_style_number <- function(decimal_places = 2, alt = FALSE) {
  fmt <- paste0("0.", paste(rep("0", decimal_places), collapse = ""))
  openxlsx::createStyle(
    fontName = SEG_FONT_NAME,
    fontSize = SEG_FONT_SIZE,
    numFmt = fmt,
    halign = "center",
    fgFill = if (alt) SEG_ROW_ALT_BG else "#FFFFFF"
  )
}


#' Create Segment Percentage Style
#'
#' @param decimal_places Integer, number of decimal places
#' @return openxlsx Style object
#' @keywords internal
seg_style_percentage <- function(decimal_places = 1) {
  fmt <- paste0("0.", paste(rep("0", decimal_places), collapse = ""), "%")
  openxlsx::createStyle(
    fontName = SEG_FONT_NAME,
    fontSize = SEG_FONT_SIZE,
    numFmt = fmt,
    halign = "center"
  )
}


#' Create Title Style
#'
#' @return openxlsx Style object
#' @keywords internal
seg_style_title <- function() {
  openxlsx::createStyle(
    fontName = SEG_FONT_NAME,
    fontSize = SEG_FONT_SIZE_TITLE,
    fontColour = SEG_BRAND_COLOUR,
    textDecoration = "bold",
    halign = "left"
  )
}


#' Create Metric Label Style (left-aligned, bold)
#'
#' @return openxlsx Style object
#' @keywords internal
seg_style_metric_label <- function() {
  openxlsx::createStyle(
    fontName = SEG_FONT_NAME,
    fontSize = SEG_FONT_SIZE,
    textDecoration = "bold",
    halign = "left"
  )
}


#' Create Conditional Fill Style
#'
#' @param level "green", "amber", or "red"
#' @return openxlsx Style object
#' @keywords internal
seg_style_conditional <- function(level = "green") {
  bg <- switch(level,
    green = SEG_GREEN_BG,
    amber = SEG_AMBER_BG,
    red   = SEG_RED_BG,
    "#FFFFFF"
  )
  openxlsx::createStyle(
    fontName = SEG_FONT_NAME,
    fontSize = SEG_FONT_SIZE,
    fgFill = bg,
    halign = "center"
  )
}


# ==============================================================================
# WORKSHEET HELPERS
# ==============================================================================

#' Apply Branded Header to Worksheet
#'
#' Writes data with styled header row, column widths, and alternating rows.
#'
#' @param wb Workbook object
#' @param sheet Sheet name
#' @param data Data frame to write
#' @param start_row Starting row (default 1)
#' @param col_widths Named vector or "auto" for auto-width
#' @return Invisible NULL
#' @export
seg_write_branded_sheet <- function(wb, sheet, data, start_row = 1,
                                     col_widths = "auto") {

  if (is.null(data) || nrow(data) == 0) return(invisible(NULL))

  # Formula injection protection: escape all character columns
  data <- seg_escape_df(data)

  n_cols <- ncol(data)
  n_rows <- nrow(data)

  # Write data
  openxlsx::writeData(wb, sheet, data, startRow = start_row, headerStyle = seg_style_header())

  # Apply alternating row shading
  for (i in seq_len(n_rows)) {
    row_idx <- start_row + i  # +1 for header
    if (i %% 2 == 0) {
      openxlsx::addStyle(wb, sheet,
        style = seg_style_data(alt = TRUE),
        rows = row_idx, cols = seq_len(n_cols),
        gridExpand = TRUE, stack = TRUE)
    }
  }

  # Set column widths
  if (identical(col_widths, "auto")) {
    openxlsx::setColWidths(wb, sheet, cols = seq_len(n_cols), widths = "auto")
  } else if (is.numeric(col_widths)) {
    openxlsx::setColWidths(wb, sheet, cols = seq_len(n_cols),
                            widths = rep_len(col_widths, n_cols))
  }

  # Freeze header row
  openxlsx::freezePane(wb, sheet, firstRow = TRUE)

  invisible(NULL)
}


#' Add Title Row to Worksheet
#'
#' @param wb Workbook object
#' @param sheet Sheet name
#' @param title Character, title text
#' @param row Integer, row number
#' @param col_span Integer, number of columns to merge
#' @return Invisible NULL
#' @keywords internal
seg_write_title <- function(wb, sheet, title, row = 1, col_span = 5) {
  openxlsx::writeData(wb, sheet, seg_escape_cell(title), startRow = row, startCol = 1)
  openxlsx::addStyle(wb, sheet, style = seg_style_title(),
                      rows = row, cols = 1)
  if (col_span > 1) {
    openxlsx::mergeCells(wb, sheet, cols = 1:col_span, rows = row)
  }
  invisible(NULL)
}


#' Add Summary Metrics Block
#'
#' Writes a key-value summary section with styled labels.
#'
#' @param wb Workbook object
#' @param sheet Sheet name
#' @param metrics Named list of label-value pairs
#' @param start_row Starting row
#' @param label_col Column for labels
#' @param value_col Column for values
#' @return Integer, next available row
#' @keywords internal
seg_write_metrics <- function(wb, sheet, metrics, start_row = 1,
                               label_col = 1, value_col = 2) {

  for (i in seq_along(metrics)) {
    row <- start_row + i - 1
    openxlsx::writeData(wb, sheet, seg_escape_cell(names(metrics)[i]),
                         startRow = row, startCol = label_col)
    metric_val <- metrics[[i]]
    if (is.character(metric_val)) metric_val <- seg_escape_cell(metric_val)
    openxlsx::writeData(wb, sheet, metric_val,
                         startRow = row, startCol = value_col)
    openxlsx::addStyle(wb, sheet, style = seg_style_metric_label(),
                        rows = row, cols = label_col)
  }

  invisible(start_row + length(metrics))
}


#' Apply Conditional Formatting to Column Based on Thresholds
#'
#' @param wb Workbook object
#' @param sheet Sheet name
#' @param col Column index
#' @param rows Row indices
#' @param green_threshold Values >= this get green
#' @param amber_threshold Values >= this get amber
#' @param red_below Values < this get red
#' @param higher_is_better Logical (default TRUE)
#' @keywords internal
seg_apply_conditional <- function(wb, sheet, col, rows,
                                   green_threshold, amber_threshold,
                                   higher_is_better = TRUE) {
  if (higher_is_better) {
    openxlsx::conditionalFormatting(wb, sheet,
      cols = col, rows = rows, type = "expression",
      rule = paste0(">=", green_threshold),
      style = seg_style_conditional("green"))
    openxlsx::conditionalFormatting(wb, sheet,
      cols = col, rows = rows, type = "expression",
      rule = paste0("<", amber_threshold),
      style = seg_style_conditional("red"))
  } else {
    openxlsx::conditionalFormatting(wb, sheet,
      cols = col, rows = rows, type = "expression",
      rule = paste0("<=", green_threshold),
      style = seg_style_conditional("green"))
    openxlsx::conditionalFormatting(wb, sheet,
      cols = col, rows = rows, type = "expression",
      rule = paste0(">", amber_threshold),
      style = seg_style_conditional("red"))
  }
}


# ==============================================================================
# CONVENIENCE: WRITE SHEETS LIST TO BRANDED EXCEL
# ==============================================================================

#' Write a Named List of Data Frames to Branded Excel
#'
#' Drop-in replacement for writexl::write_xlsx(sheets, path).
#' Creates a workbook with branded formatting on every sheet.
#'
#' @param sheets Named list of data frames
#' @param file_path Output file path
#' @param module Module name for atomic save logging (default "SEGMENT")
#' @return Invisible file_path
#' @export
seg_write_xlsx <- function(sheets, file_path, module = "SEGMENT") {
  wb <- openxlsx::createWorkbook()

  for (sheet_name in names(sheets)) {
    # Truncate sheet name to 31 chars (Excel limit)
    safe_name <- substr(sheet_name, 1, 31)
    openxlsx::addWorksheet(wb, safe_name)

    sheet_data <- sheets[[sheet_name]]
    if (!is.null(sheet_data) && is.data.frame(sheet_data) && nrow(sheet_data) > 0) {
      seg_write_branded_sheet(wb, safe_name, sheet_data)
    } else if (!is.null(sheet_data) && is.data.frame(sheet_data)) {
      # Empty data frame — write headers only
      openxlsx::writeData(wb, safe_name, sheet_data, headerStyle = seg_style_header())
    }
  }

  # Save with atomic write if available
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, file_path, module = module)
    if (!save_result$success) {
      warning(sprintf("[%s] Failed to save: %s", module, save_result$error))
    }
  } else {
    openxlsx::saveWorkbook(wb, file_path, overwrite = TRUE)
  }

  invisible(file_path)
}
