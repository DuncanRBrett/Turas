# ==============================================================================
# TEMPLATE_STYLES.R - TURAS Shared Template Infrastructure
# ==============================================================================
# Shared colour palette, style factories, and helper functions for generating
# professional, hardened Excel config templates across all TURAS modules.
#
# USAGE:
#   source("modules/shared/template_styles.R")
#   # Then use write_settings_sheet() and write_table_sheet() in your module
#
# PROVIDES:
#   - Colour palette constants (.TPL_*)
#   - Style factory functions (make_*_style)
#   - write_settings_sheet() - Settings with sections, dropdowns, help text
#   - write_table_sheet()    - Tables with headers, dropdowns, example rows
#
# ==============================================================================

library(openxlsx)

# ==============================================================================
# COLOUR PALETTE
# ==============================================================================

.TPL_NAVY      <- "#323367"
.TPL_GOLD      <- "#CC9900"
.TPL_WHITE     <- "#FFFFFF"
.TPL_LIGHT_BG  <- "#F8F9FA"
.TPL_SECTION   <- "#E8EAF6"
.TPL_REQUIRED  <- "#FFF3E0"
.TPL_OPTIONAL  <- "#F1F8E9"
.TPL_INPUT     <- "#FFFDE7"
.TPL_LOCKED    <- "#ECEFF1"
.TPL_HEADER_FG <- "#FFFFFF"
.TPL_BORDER    <- "#B0BEC5"
.TPL_RED       <- "#D32F2F"
.TPL_GREEN     <- "#388E3C"
.TPL_HELP_FG   <- "#546E7A"

# ==============================================================================
# STYLE FACTORIES
# ==============================================================================

make_header_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 11, fontColour = .TPL_HEADER_FG,
    fgFill = .TPL_NAVY, halign = "left", valign = "center",
    textDecoration = "bold", border = "TopBottomLeftRight",
    borderColour = .TPL_NAVY, wrapText = TRUE
  )
}

make_section_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 11, fontColour = .TPL_NAVY,
    fgFill = .TPL_SECTION, halign = "left", valign = "center",
    textDecoration = "bold", border = "TopBottomLeftRight",
    borderColour = .TPL_BORDER
  )
}

make_required_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 10,
    fgFill = .TPL_REQUIRED, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER
  )
}

make_optional_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 10,
    fgFill = .TPL_OPTIONAL, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER
  )
}

make_input_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 10,
    fgFill = .TPL_INPUT, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER
  )
}

make_locked_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 10, fontColour = .TPL_HELP_FG,
    fgFill = .TPL_LOCKED, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER,
    wrapText = TRUE
  )
}

make_help_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 9, fontColour = .TPL_HELP_FG,
    fgFill = .TPL_LIGHT_BG, halign = "left", valign = "center",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER,
    wrapText = TRUE, textDecoration = "italic"
  )
}

make_title_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 14, fontColour = .TPL_NAVY,
    textDecoration = "bold", halign = "left", valign = "center"
  )
}

make_subtitle_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 10, fontColour = .TPL_HELP_FG,
    halign = "left", valign = "center", textDecoration = "italic"
  )
}

make_legend_label_style <- function(bg_colour) {
  createStyle(
    fontName = "Calibri", fontSize = 9,
    fgFill = bg_colour, border = "TopBottomLeftRight",
    borderColour = .TPL_BORDER, halign = "center", valign = "center"
  )
}

make_example_style <- function() {
  createStyle(
    fontName = "Calibri", fontSize = 10,
    fgFill = "#E3F2FD",
    border = "TopBottomLeftRight", borderColour = .TPL_BORDER,
    halign = "left", valign = "center",
    fontColour = "#37474F"
  )
}


# ==============================================================================
# HELPER: Write a settings sheet with sections, help text, and dropdowns
# ==============================================================================

#' Write a formatted settings sheet
#'
#' Creates a professional settings sheet with section grouping, colour-coded
#' required/optional markers, dropdown validation, numeric range validation,
#' help text, and frozen panes.
#'
#' @param wb Workbook object
#' @param sheet_name Name for the sheet
#' @param settings_def List of section definitions. Each section has:
#'   \itemize{
#'     \item{section_name}{Character - section header text}
#'     \item{fields}{List of field definitions, each with:
#'       name, required (logical), default, description,
#'       valid_values_text, dropdown (character vector),
#'       numeric_range (c(min, max)), integer_range (c(min, max))}
#'   }
#' @param title Sheet title (row 1)
#' @param subtitle Sheet subtitle (row 2)
#' @return Invisibly returns the next available row number
write_settings_sheet <- function(wb, sheet_name, settings_def, title, subtitle) {
  addWorksheet(wb, sheet_name, gridLines = FALSE)

  # Column widths: Setting | Value | Required? | Description | Valid Values
  setColWidths(wb, sheet_name, cols = 1:5, widths = c(38, 28, 12, 55, 35))

  # Title row
  writeData(wb, sheet_name, x = title, startRow = 1, startCol = 1)
  addStyle(wb, sheet_name, make_title_style(), rows = 1, cols = 1)
  mergeCells(wb, sheet_name, cols = 1:5, rows = 1)

  # Subtitle row
  writeData(wb, sheet_name, x = subtitle, startRow = 2, startCol = 1)
  addStyle(wb, sheet_name, make_subtitle_style(), rows = 2, cols = 1)
  mergeCells(wb, sheet_name, cols = 1:5, rows = 2)

  # Legend row
  row <- 3
  writeData(wb, sheet_name, x = "Legend:", startRow = row, startCol = 1)
  addStyle(wb, sheet_name, createStyle(fontName = "Calibri", fontSize = 9,
    textDecoration = "bold"), rows = row, cols = 1)

  writeData(wb, sheet_name, x = "Required", startRow = row, startCol = 2)
  addStyle(wb, sheet_name, make_legend_label_style(.TPL_REQUIRED), rows = row, cols = 2)

  writeData(wb, sheet_name, x = "Optional", startRow = row, startCol = 3)
  addStyle(wb, sheet_name, make_legend_label_style(.TPL_OPTIONAL), rows = row, cols = 3)

  writeData(wb, sheet_name, x = "Your Input", startRow = row, startCol = 4)
  addStyle(wb, sheet_name, make_legend_label_style(.TPL_INPUT), rows = row, cols = 4)

  writeData(wb, sheet_name, x = "Read Only", startRow = row, startCol = 5)
  addStyle(wb, sheet_name, make_legend_label_style(.TPL_LOCKED), rows = row, cols = 5)

  # Header row
  row <- 5
  headers <- c("Setting", "Value", "Required?", "Description", "Valid Values / Notes")
  writeData(wb, sheet_name, x = data.frame(t(headers)), startRow = row, startCol = 1,
            colNames = FALSE)
  addStyle(wb, sheet_name, make_header_style(), rows = row, cols = 1:5, gridExpand = TRUE)

  row <- 6

  for (section in settings_def) {
    # Section header row
    writeData(wb, sheet_name, x = section$section_name, startRow = row, startCol = 1)
    addStyle(wb, sheet_name, make_section_style(), rows = row, cols = 1:5, gridExpand = TRUE)
    mergeCells(wb, sheet_name, cols = 1:5, rows = row)
    row <- row + 1

    for (field in section$fields) {
      # Column A: Setting name
      writeData(wb, sheet_name, x = field$name, startRow = row, startCol = 1)
      is_req <- isTRUE(field$required)
      addStyle(wb, sheet_name,
               if (is_req) make_required_style() else make_optional_style(),
               rows = row, cols = 1)

      # Column B: Default value (editable)
      default_val <- if (!is.null(field$default)) field$default else ""
      writeData(wb, sheet_name, x = default_val, startRow = row, startCol = 2)
      addStyle(wb, sheet_name, make_input_style(), rows = row, cols = 2)

      # Column C: Required marker
      req_text <- if (is_req) "REQUIRED" else "Optional"
      writeData(wb, sheet_name, x = req_text, startRow = row, startCol = 3)
      addStyle(wb, sheet_name,
               createStyle(fontName = "Calibri", fontSize = 9,
                           fontColour = if (is_req) .TPL_RED else .TPL_GREEN,
                           fgFill = if (is_req) .TPL_REQUIRED else .TPL_OPTIONAL,
                           halign = "center", valign = "center",
                           textDecoration = if (is_req) "bold" else ""),
               rows = row, cols = 3)

      # Column D: Description
      writeData(wb, sheet_name, x = field$description, startRow = row, startCol = 4)
      addStyle(wb, sheet_name, make_help_style(), rows = row, cols = 4)

      # Column E: Valid values
      valid_text <- if (!is.null(field$valid_values_text)) field$valid_values_text else ""
      writeData(wb, sheet_name, x = valid_text, startRow = row, startCol = 5)
      addStyle(wb, sheet_name, make_locked_style(), rows = row, cols = 5)

      # Data validation (dropdown) if options are specified
      if (!is.null(field$dropdown)) {
        dataValidation(wb, sheet_name,
                       col = 2, rows = row,
                       type = "list",
                       value = paste0('"', paste(field$dropdown, collapse = ","), '"'),
                       allowBlank = !is_req,
                       showInputMsg = TRUE,
                       showErrorMsg = TRUE)
      }

      # Numeric validation if specified
      if (!is.null(field$numeric_range)) {
        rng <- field$numeric_range
        dataValidation(wb, sheet_name,
                       col = 2, rows = row,
                       type = "decimal",
                       operator = "between",
                       value = c(rng[1], rng[2]),
                       allowBlank = !is_req,
                       showInputMsg = TRUE,
                       showErrorMsg = TRUE)
      }

      # Integer validation if specified
      if (!is.null(field$integer_range)) {
        rng <- field$integer_range
        dataValidation(wb, sheet_name,
                       col = 2, rows = row,
                       type = "whole",
                       operator = "between",
                       value = c(rng[1], rng[2]),
                       allowBlank = !is_req,
                       showInputMsg = TRUE,
                       showErrorMsg = TRUE)
      }

      row <- row + 1
    }
  }

  # Freeze panes: freeze header row
  freezePane(wb, sheet_name, firstActiveRow = 6, firstActiveCol = 1)

  invisible(row)
}


# ==============================================================================
# HELPER: Write a table sheet with headers, dropdowns, and help
# ==============================================================================

#' Write a formatted table sheet (Questions, Options, Variables, etc.)
#'
#' Creates a professional table sheet with column headers, help descriptions,
#' dropdown validation, example data rows, and blank formatted rows for input.
#'
#' @param wb Workbook object
#' @param sheet_name Sheet name
#' @param columns_def List of column definitions. Each column has:
#'   \itemize{
#'     \item{name}{Character - column header text}
#'     \item{width}{Numeric - column width}
#'     \item{required}{Logical - is this column required?}
#'     \item{description}{Character - help text}
#'     \item{dropdown}{Character vector - dropdown options (optional)}
#'     \item{integer_range}{c(min, max) - integer validation (optional)}
#'     \item{numeric_range}{c(min, max) - decimal validation (optional)}
#'   }
#' @param title Sheet title
#' @param subtitle Sheet subtitle
#' @param example_rows Optional list of named lists for example data
#' @param num_blank_rows Number of blank rows to format (default 50)
write_table_sheet <- function(wb, sheet_name, columns_def, title, subtitle,
                              example_rows = NULL, num_blank_rows = 50) {
  addWorksheet(wb, sheet_name, gridLines = FALSE)

  # Set column widths
  col_widths <- vapply(columns_def, function(c) c$width, numeric(1))
  setColWidths(wb, sheet_name, cols = seq_along(columns_def), widths = col_widths)

  n_cols <- length(columns_def)

  # Title
  writeData(wb, sheet_name, x = title, startRow = 1, startCol = 1)
  addStyle(wb, sheet_name, make_title_style(), rows = 1, cols = 1)
  mergeCells(wb, sheet_name, cols = 1:n_cols, rows = 1)

  # Subtitle
  writeData(wb, sheet_name, x = subtitle, startRow = 2, startCol = 1)
  addStyle(wb, sheet_name, make_subtitle_style(), rows = 2, cols = 1)
  mergeCells(wb, sheet_name, cols = 1:n_cols, rows = 2)

  # Row 3: Column headers
  for (i in seq_along(columns_def)) {
    col_def <- columns_def[[i]]
    writeData(wb, sheet_name, x = col_def$name, startRow = 3, startCol = i)
  }
  addStyle(wb, sheet_name, make_header_style(), rows = 3, cols = 1:n_cols, gridExpand = TRUE)

  # Row 4: Required/Optional + Description
  for (i in seq_along(columns_def)) {
    col_def <- columns_def[[i]]
    is_req <- isTRUE(col_def$required)
    req_marker <- if (is_req) "[REQUIRED] " else "[Optional] "
    help_text <- paste0(req_marker, col_def$description)
    writeData(wb, sheet_name, x = help_text, startRow = 4, startCol = i)
  }
  addStyle(wb, sheet_name, make_help_style(), rows = 4, cols = 1:n_cols, gridExpand = TRUE)
  setRowHeights(wb, sheet_name, rows = 4, heights = 45)

  # Data rows start at 5
  data_start <- 5

  # Write example rows if provided
  n_examples <- 0
  if (!is.null(example_rows) && length(example_rows) > 0) {
    n_examples <- length(example_rows)
    for (r in seq_along(example_rows)) {
      row_data <- example_rows[[r]]
      current_row <- data_start + r - 1
      for (i in seq_along(columns_def)) {
        col_name <- columns_def[[i]]$name
        val <- if (col_name %in% names(row_data)) row_data[[col_name]] else ""
        if (!is.null(val) && !is.na(val)) {
          writeData(wb, sheet_name, x = val, startRow = current_row, startCol = i)
        }
      }
      addStyle(wb, sheet_name, make_example_style(),
               rows = current_row, cols = 1:n_cols, gridExpand = TRUE)
    }
  }

  # Blank formatted rows for user input
  blank_start <- data_start + n_examples
  blank_end <- blank_start + num_blank_rows - 1
  for (r in blank_start:blank_end) {
    addStyle(wb, sheet_name, make_input_style(), rows = r, cols = 1:n_cols, gridExpand = TRUE)
  }

  # Apply data validation to all data rows (examples + blanks)
  all_data_start <- data_start
  all_data_end <- blank_end
  for (i in seq_along(columns_def)) {
    col_def <- columns_def[[i]]
    if (!is.null(col_def$dropdown)) {
      dataValidation(wb, sheet_name,
                     col = i, rows = all_data_start:all_data_end,
                     type = "list",
                     value = paste0('"', paste(col_def$dropdown, collapse = ","), '"'),
                     allowBlank = !isTRUE(col_def$required),
                     showInputMsg = TRUE,
                     showErrorMsg = TRUE)
    }
    if (!is.null(col_def$integer_range)) {
      rng <- col_def$integer_range
      dataValidation(wb, sheet_name,
                     col = i, rows = all_data_start:all_data_end,
                     type = "whole",
                     operator = "between",
                     value = c(rng[1], rng[2]),
                     allowBlank = !isTRUE(col_def$required),
                     showInputMsg = TRUE,
                     showErrorMsg = TRUE)
    }
    if (!is.null(col_def$numeric_range)) {
      rng <- col_def$numeric_range
      dataValidation(wb, sheet_name,
                     col = i, rows = all_data_start:all_data_end,
                     type = "decimal",
                     operator = "between",
                     value = c(rng[1], rng[2]),
                     allowBlank = !isTRUE(col_def$required),
                     showInputMsg = TRUE,
                     showErrorMsg = TRUE)
    }
  }

  # Freeze panes
  freezePane(wb, sheet_name, firstActiveRow = data_start, firstActiveCol = 1)

  invisible(NULL)
}
