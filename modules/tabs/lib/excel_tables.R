# ==============================================================================
# MODULE: EXCEL_TABLES.R
# ==============================================================================
#
# PURPOSE:
#   Write question tables and base rows for Excel crosstab output
#
# FUNCTIONS:
#   - write_question_table() - Write a single question's results
#   - write_base_rows() - Write base size rows
#
# DEPENDENCIES:
#   - openxlsx (Excel writing)
#   - excel_styles.R (get_row_style)
#
# VERSION: 1.3.0 - Extracted from excel_writer.R for maintainability
# DATE: 2025-12-27
# CHANGES: Refactored into focused module for better organization
# ==============================================================================

#' Write Question Table
#'
#' Writes a single question's results to Excel.
#'
#' @param wb Workbook object
#' @param sheet Character, sheet name
#' @param result List, question result with table and metadata
#' @param banner_info List, banner structure
#' @param styles List, style objects
#' @param start_row Integer, starting row
#' @param config List, configuration
#' @return Integer, next row number
#' @export
write_question_table <- function(wb, sheet, result, banner_info, styles,
                                start_row, config) {

  current_row <- start_row

  # Write question text
  question_text <- if (!is.null(result$question_text)) {
    result$question_text
  } else {
    result$question_code
  }

  openxlsx::writeData(
    wb, sheet,
    question_text,
    startRow = current_row,
    startCol = 1
  )
  openxlsx::addStyle(
    wb, sheet, styles$question,
    rows = current_row,
    cols = 1
  )
  current_row <- current_row + 1

  # Write base filter if present
  if (!is.null(result$base_filter) && result$base_filter != "") {
    openxlsx::writeData(
      wb, sheet,
      paste("Base:", result$base_filter),
      startRow = current_row,
      startCol = 1
    )
    openxlsx::addStyle(
      wb, sheet, styles$filter,
      rows = current_row,
      cols = 1
    )
    current_row <- current_row + 1
  }

  # Write base sizes if present
  if (!is.null(result$bases)) {
    current_row <- write_base_rows(
      wb, sheet, banner_info, result$bases, styles, current_row, config
    )
  }

  # Write table data
  table <- result$table

  for (row_idx in seq_len(nrow(table))) {
    row_data <- table[row_idx, ]
    row_type <- as.character(row_data$RowType)

    # Write row label and type
    openxlsx::writeData(
      wb, sheet,
      as.character(row_data$RowLabel),
      startRow = current_row,
      startCol = 1
    )
    openxlsx::writeData(
      wb, sheet,
      row_type,
      startRow = current_row,
      startCol = 2
    )

    # Write values for each banner column
    col_offset <- 3
    for (key in banner_info$internal_keys) {
      if (key %in% names(row_data)) {
        value <- row_data[[key]]

        # Convert to numeric if possible
        if (is.character(value) && !grepl("[a-zA-Z]", value)) {
          value <- suppressWarnings(as.numeric(value))
        }

        openxlsx::writeData(
          wb, sheet,
          value,
          startRow = current_row,
          startCol = col_offset
        )

        # Apply style based on row type
        style <- get_row_style(row_type, styles)
        if (!is.null(style)) {
          openxlsx::addStyle(
            wb, sheet, style,
            rows = current_row,
            cols = col_offset
          )
        }

        col_offset <- col_offset + 1
      }
    }

    # Apply row label style
    openxlsx::addStyle(
      wb, sheet, styles$row_label,
      rows = current_row,
      cols = 1
    )

    current_row <- current_row + 1
  }

  return(current_row)
}

#' Write Base Rows (Proper vector transposition)
#'
#' Writes base size rows (unweighted, weighted, effective) with conditional logic.
#'
#' @param wb Workbook object
#' @param sheet Character, sheet name
#' @param banner_info List, banner structure
#' @param question_bases List, base sizes by column
#' @param styles List, style objects
#' @param current_row Integer, starting row
#' @param config List, configuration with apply_weighting, show_unweighted_n, show_effective_n
#' @return Integer, next row number
#' @export
write_base_rows <- function(wb, sheet, banner_info, question_bases, styles,
                            current_row, config) {
  internal_keys <- banner_info$internal_keys
  total_cols <- 2 + length(banner_info$columns)

  # Constants (ensure these are defined)
  UNWEIGHTED_BASE_LABEL <- "Base (unweighted)"
  WEIGHTED_BASE_LABEL <- "Base (weighted)"
  EFFECTIVE_BASE_LABEL <- "Effective base"
  BASE_ROW_LABEL <- "Base (n=)"

  if (config$apply_weighting) {
    if (config$show_unweighted_n) {
      base_values <- sapply(internal_keys, function(key) {
        as.numeric(question_bases[[key]]$unweighted)
      })

      openxlsx::writeData(wb, sheet, "", startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::writeData(wb, sheet, UNWEIGHTED_BASE_LABEL, startRow = current_row, startCol = 2, colNames = FALSE)
      openxlsx::writeData(wb, sheet, t(as.matrix(base_values)), startRow = current_row, startCol = 3, colNames = FALSE)

      openxlsx::addStyle(wb, sheet, styles$base, rows = current_row,
                        cols = seq_len(total_cols), gridExpand = TRUE)
      current_row <- current_row + 1
    }

    weighted_values <- sapply(internal_keys, function(key) {
      round(as.numeric(question_bases[[key]]$weighted), 0)
    })

    openxlsx::writeData(wb, sheet, "", startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::writeData(wb, sheet, WEIGHTED_BASE_LABEL, startRow = current_row, startCol = 2, colNames = FALSE)
    openxlsx::writeData(wb, sheet, t(as.matrix(weighted_values)), startRow = current_row, startCol = 3, colNames = FALSE)

    openxlsx::addStyle(wb, sheet, styles$base, rows = current_row,
                      cols = seq_len(total_cols), gridExpand = TRUE)
    current_row <- current_row + 1

    if (config$show_effective_n) {
      eff_values <- sapply(internal_keys, function(key) {
        round(as.numeric(question_bases[[key]]$effective), 0)
      })

      openxlsx::writeData(wb, sheet, "", startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::writeData(wb, sheet, EFFECTIVE_BASE_LABEL, startRow = current_row, startCol = 2, colNames = FALSE)
      openxlsx::writeData(wb, sheet, t(as.matrix(eff_values)), startRow = current_row, startCol = 3, colNames = FALSE)

      openxlsx::addStyle(wb, sheet, styles$base, rows = current_row,
                        cols = seq_len(total_cols), gridExpand = TRUE)
      current_row <- current_row + 1
    }
  } else {
    base_values <- sapply(internal_keys, function(key) {
      as.numeric(question_bases[[key]]$unweighted)
    })

    openxlsx::writeData(wb, sheet, "", startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::writeData(wb, sheet, BASE_ROW_LABEL, startRow = current_row, startCol = 2, colNames = FALSE)
    openxlsx::writeData(wb, sheet, t(as.matrix(base_values)), startRow = current_row, startCol = 3, colNames = FALSE)

    openxlsx::addStyle(wb, sheet, styles$base, rows = current_row,
                      cols = seq_len(total_cols), gridExpand = TRUE)
    current_row <- current_row + 1
  }

  return(current_row)
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs excel_tables module loaded")

# ==============================================================================
# END OF MODULE: EXCEL_TABLES.R
# ==============================================================================
