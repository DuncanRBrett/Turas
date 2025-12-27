# ==============================================================================
# MODULE: EXCEL_HEADERS.R
# ==============================================================================
#
# PURPOSE:
#   Write banner headers and column letters for Excel crosstab output
#
# FUNCTIONS:
#   - write_banner_headers() - Write banner column headers
#   - write_column_letters() - Write column letter row (A, B, C, etc.)
#
# DEPENDENCIES:
#   - openxlsx (Excel writing)
#
# VERSION: 1.3.0 - Extracted from excel_writer.R for maintainability
# DATE: 2025-12-27
# CHANGES: Refactored into focused module for better organization
# ==============================================================================

#' Write Banner Headers
#'
#' Writes banner column headers at top of sheet.
#'
#' @param wb Workbook object
#' @param sheet Character, sheet name
#' @param banner_info List, banner structure
#' @param styles List, style objects
#' @return Integer, next row number
#' @export
write_banner_headers <- function(wb, sheet, banner_info, styles) {

  current_row <- 1

  # Write banner group labels row (BannerLabel from config)
  # This row shows the grouping labels above the column options
  if (!is.null(banner_info$banner_headers) && nrow(banner_info$banner_headers) > 0) {
    # Create banner label row: "", "" for Question/Type columns, then labels at start positions
    banner_label_row <- rep("", length(banner_info$column_labels) + 2)

    for (i in seq_len(nrow(banner_info$banner_headers))) {
      start_col <- banner_info$banner_headers$start_col[i]
      label <- banner_info$banner_headers$label[i]

      # start_col is 2-based (starts after Total), add 2 for Question/Type columns
      col_idx <- start_col + 2  # +2 for Question and Type columns
      if (col_idx <= length(banner_label_row)) {
        banner_label_row[col_idx] <- label
      }
    }

    openxlsx::writeData(
      wb, sheet,
      t(as.matrix(banner_label_row)),
      startRow = current_row,
      startCol = 1,
      colNames = FALSE
    )

    openxlsx::addStyle(
      wb, sheet, styles$banner,
      rows = current_row,
      cols = 1:length(banner_label_row),
      gridExpand = TRUE
    )

    current_row <- current_row + 1
  }

  # Write column options row
  header_data <- c("Question", "Type", banner_info$column_labels)

  openxlsx::writeData(
    wb, sheet,
    t(as.matrix(header_data)),
    startRow = current_row,
    startCol = 1,
    colNames = FALSE
  )

  # Apply banner style
  openxlsx::addStyle(
    wb, sheet, styles$banner,
    rows = current_row,
    cols = 1:length(header_data),
    gridExpand = TRUE
  )

  # Write column letters (A, B, C, etc.)
  current_row <- current_row + 1
  letter_data <- c("", "", banner_info$letters)

  openxlsx::writeData(
    wb, sheet,
    t(as.matrix(letter_data)),
    startRow = current_row,
    startCol = 1,
    colNames = FALSE
  )

  # Apply letter style
  openxlsx::addStyle(
    wb, sheet, styles$letter,
    rows = current_row,
    cols = 3:length(letter_data),
    gridExpand = TRUE
  )

  return(current_row + 1)
}

#' Write Column Letters
#'
#' Writes column letter row (A, B, C, etc.) below banner headers.
#'
#' @param wb Workbook object
#' @param sheet Character, sheet name
#' @param banner_info List, banner structure
#' @param styles List, style objects
#' @param current_row Integer, starting row
#' @return Integer, next row number
#' @export
write_column_letters <- function(wb, sheet, banner_info, styles, current_row) {
  total_cols <- 2 + length(banner_info$columns)

  letter_row <- c("", "", banner_info$letters)
  openxlsx::writeData(wb, sheet, t(letter_row),
                     startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet, styles$letter, rows = current_row,
                    cols = seq_len(total_cols), gridExpand = TRUE)

  return(current_row + 1)
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs excel_headers module loaded")

# ==============================================================================
# END OF MODULE: EXCEL_HEADERS.R
# ==============================================================================
