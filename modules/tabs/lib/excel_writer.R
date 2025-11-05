# ==============================================================================
# MODULE 13: EXCEL_WRITER.R
# ==============================================================================
#
# PURPOSE:
#   Write crosstab results to Excel workbook with proper formatting
#
# FUNCTIONS:
#   - write_crosstab_workbook() - Main writer
#   - create_excel_styles() - Style definitions
#   - write_banner_headers() - Write banner headers
#   - write_base_rows() - Write base size rows
#   - write_question_table() - Write question results
#
# DEPENDENCIES:
#   - openxlsx (Excel creation)
#   - utilities.R (formatting, logging)
#
# VERSION: 1.0.0
# DATE: 2025-10-25
# ==============================================================================

# Require openxlsx
if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Package 'openxlsx' is required for excel_writer module")
}

# ==============================================================================
# MAIN EXCEL WRITER
# ==============================================================================

#' Write Crosstab Workbook
#'
#' Creates complete Excel workbook with crosstab results.
#'
#' @param output_file Character, output file path
#' @param all_results List, all question results
#' @param banner_info List, banner structure
#' @param config List, configuration
#' @param project_info List, project metadata
#' @return TRUE if successful
#' @export
write_crosstab_workbook <- function(output_file, all_results, banner_info,
                                   config, project_info = NULL) {
  
  log_message("Creating Excel workbook...", level = "INFO", verbose = config$verbose)
  
  # Create workbook
  wb <- openxlsx::createWorkbook()
  
  # Create styles
  styles <- create_excel_styles(
    decimal_separator = config$decimal_separator,
    decimal_places_percent = config$decimal_places_percent,
    decimal_places_ratings = config$decimal_places_ratings,
    decimal_places_index = config$decimal_places_index,
    decimal_places_numeric = config$decimal_places_numeric
  )
  
  # Add main results sheet
  sheet_name <- "Crosstabs"
  openxlsx::addWorksheet(wb, sheet_name)
  
  # Write banner headers
  current_row <- write_banner_headers(wb, sheet_name, banner_info, styles)
  
  # Write each question
  for (i in seq_along(all_results)) {
    result <- all_results[[i]]
    
    if (!is.null(result$table) && nrow(result$table) > 0) {
      current_row <- write_question_table(
        wb, sheet_name, result, banner_info, styles, current_row, config
      )
      current_row <- current_row + 2  # Add spacing
    }
  }
  
  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 40)
  openxlsx::setColWidths(wb, sheet_name, cols = 2, widths = 10)
  openxlsx::setColWidths(wb, sheet_name, 
                        cols = 3:(3 + length(banner_info$internal_keys) - 1),
                        widths = 12)
  
  # Save workbook
  safe_execute(
    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE),
    default = FALSE,
    error_msg = sprintf("Failed to save Excel file: %s", output_file)
  )
  
  log_message(
    sprintf("Excel file created: %s", output_file),
    level = "INFO",
    verbose = config$verbose
  )
  
  return(TRUE)
}

# ==============================================================================
# STYLE CREATION
# ==============================================================================

#' Create Excel Styles
#'
#' Creates all formatting styles for Excel output.
#'
#' @param decimal_separator Character, "." or ","
#' @param decimal_places_percent Integer, decimals for percentages
#' @param decimal_places_ratings Integer, decimals for ratings
#' @param decimal_places_index Integer, decimals for indices
#' @param decimal_places_numeric Integer, decimals for numeric
#' @return List of openxlsx style objects
#' @export
create_excel_styles <- function(decimal_separator = ".",
                               decimal_places_percent = 0,
                               decimal_places_ratings = 1,
                               decimal_places_index = 1,
                               decimal_places_numeric = 1) {
  
  sep <- decimal_separator
  
  list(
    banner = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "white",
      fgFill = "#1F4E79", halign = "center", valign = "center",
      textDecoration = "bold", border = "TopBottomLeftRight",
      borderColour = "black"
    ),
    
    question = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", textDecoration = "bold",
      halign = "left", valign = "center"
    ),
    
    filter = openxlsx::createStyle(
      fontSize = 10, fontName = "Aptos", fontColour = "#0066CC",
      halign = "left", valign = "center"
    ),
    
    letter = openxlsx::createStyle(
      fontSize = 10, fontName = "Aptos", fontColour = "#595959",
      halign = "center", valign = "center", textDecoration = "bold"
    ),
    
    base = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", halign = "center",
      valign = "center", textDecoration = "bold"
    ),
    
    frequency = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", fontColour = "#595959",
      halign = "right", valign = "center", numFmt = "#,##0"
    ),
    
    column_pct = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center",
      numFmt = if (decimal_places_percent == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_percent), collapse = ""))
      }
    ),
    
    row_pct = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "#595959",
      halign = "left", valign = "center",
      numFmt = if (decimal_places_percent == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_percent), collapse = ""))
      }
    ),
    
    sig = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center"
    ),
    
    rating_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = if (decimal_places_ratings == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_ratings), collapse = ""))
      }
    ),
    
    numeric_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = if (decimal_places_numeric == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_numeric), collapse = ""))
      }
    ),
    
    index_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = if (decimal_places_index == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_index), collapse = ""))
      }
    ),
    
    score_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = if (decimal_places_percent == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_percent), collapse = ""))
      }
    ),
    
    row_label = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos",
      halign = "left", valign = "center"
    ),

    stddev_style = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", fontColour = "#595959",
      halign = "center", valign = "center", fgFill = "#F2F2F2",
      numFmt = if (decimal_places_ratings == 0) {
        "0"
      } else {
        paste0("0", sep, paste(rep("0", decimal_places_ratings), collapse = ""))
      }
    ),

    header = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", textDecoration = "bold",
      fgFill = "#1F4E79", fontColour = "white",
      border = "TopBottomLeftRight", borderColour = "black"
    ),

    section = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", textDecoration = "bold",
      fgFill = "#E7E6E6"
    ),

    warning = openxlsx::createStyle(
      fgFill = "#FFEB9C", fontColour = "#9C6500"
    ),

    caution = openxlsx::createStyle(
      fgFill = "#FFF4CC", fontColour = "#7F6000"
    ),

    error = openxlsx::createStyle(
      fgFill = "#FFC7CE", fontColour = "#9C0006"
    )
  )
}

# ==============================================================================
# BANNER HEADERS
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
  
  # Write banner labels
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
# WRITE QUESTION TABLE
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
      wb, sheet, banner_info, result$bases, styles, current_row
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

# ==============================================================================
# WRITE BASE ROWS
# ==============================================================================

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
# HELPER FUNCTIONS
# ==============================================================================

#' Get Row Style
#'
#' Returns appropriate style for a row type.
#'
#' @param row_type Character, row type
#' @param styles List, style objects
#' @return Style object or NULL
#' @export
get_row_style <- function(row_type, styles) {
  switch(row_type,
    "Frequency" = styles$frequency,
    "Column %" = styles$column_pct,
    "Row %" = styles$row_pct,
    "Average" = styles$rating_style,
    "Index" = styles$index_style,
    "Score" = styles$score_style,
    "StdDev" = styles$stddev_style,
    "Median" = styles$numeric_style,
    "Mode" = styles$numeric_style,
    "Outliers" = styles$base,
    "Sig." = styles$sig,
    "ChiSquare" = styles$sig,
    styles$base  # Default case for unrecognized types
  )
}

# ==============================================================================
# SUMMARY SHEET CREATION
# ==============================================================================

#' Create Summary Sheet
#'
#' Creates comprehensive summary sheet with project info and question list.
#'
#' @param wb Workbook object
#' @param project_info List, project metadata
#' @param all_results List, all question results
#' @param config List, configuration
#' @param styles List, style objects
#' @param script_version Character, script version (default: "9.9")
#' @param total_column_name Character, name of total column (default: "Total")
#' @param very_small_base_size Numeric, very small base threshold (default: 10)
#' @return Invisible NULL
#' @export
create_summary_sheet <- function(wb, project_info, all_results, config, styles,
                                 script_version = "9.9",
                                 total_column_name = "Total",
                                 very_small_base_size = 10) {
  openxlsx::addWorksheet(wb, "Summary")

  summary_rows <- list(
    c("PROJECT INFORMATION", ""),
    c("Project Name", project_info$project_name),
    c("Analysis Date", as.character(Sys.Date())),
    c("Script Version", script_version),
    c("", ""),
    c("DATA SUMMARY", ""),
    c("Total Responses", as.character(project_info$total_responses)),
    c("Questions Analyzed", as.character(length(all_results))),
    c("", ""),
    c("WEIGHTING", ""),
    c("Weighting Applied", if (config$apply_weighting) "YES" else "NO"),
    c("Weight Variable", if (config$apply_weighting) config$weight_variable else "N/A"),
    c("Effective Sample Size", as.character(project_info$effective_n)),
    c("", ""),
    c("SIGNIFICANCE TESTING", ""),
    c("Enabled", if (config$enable_significance_testing) "YES" else "NO"),
    c("Alpha (p-value threshold)", if (config$enable_significance_testing)
      sprintf("%.3f", config$alpha) else "N/A"),
    c("Minimum Base Size", if (config$enable_significance_testing)
      as.character(config$significance_min_base) else "N/A"),
    c("Bonferroni Correction", if (config$enable_significance_testing &&
      config$bonferroni_correction) "YES" else "NO"),
    c("", ""),
    c("DISPLAY SETTINGS", ""),
    c("Show Frequency", if (config$show_frequency) "YES" else "NO"),
    c("Show Column %", if (config$show_percent_column) "YES" else "NO"),
    c("Show Row %", if (config$show_percent_row) "YES" else "NO"),
    c("Zero Division Display", if (config$zero_division_as_blank) "Blank" else "Zero"),
    c("Decimal Places (Percent)", as.character(config$decimal_places_percent)),
    c("Decimal Places (Ratings)", as.character(config$decimal_places_ratings)),
    c("Decimal Places (Index)", as.character(config$decimal_places_index)),
    c("Decimal Separator", config$decimal_separator),
    c("", ""),
    c("BANNER INFORMATION", ""),
    c("Total Banner Columns", as.character(project_info$total_banner_cols)),
    c("Banner Questions", as.character(project_info$num_banner_questions))
  )

  summary_df <- as.data.frame(do.call(rbind, summary_rows),
                              stringsAsFactors = FALSE)
  names(summary_df) <- c("Setting", "Value")

  openxlsx::writeData(wb, "Summary", summary_df, startRow = 1, colNames = TRUE)

  openxlsx::addStyle(wb, "Summary", styles$header, rows = 1, cols = 1:2,
                    gridExpand = TRUE)

  section_rows <- c(2, 7, 11, 16, 22, 32)
  for (row in section_rows) {
    if (row <= nrow(summary_df) + 1) {
      openxlsx::addStyle(wb, "Summary", styles$section, rows = row,
                        cols = 1:2, gridExpand = TRUE)
    }
  }

  openxlsx::setColWidths(wb, "Summary", cols = 1:2, widths = c(30, 40))

  add_question_list(wb, all_results, config, styles, nrow(summary_df) + 3,
                   total_column_name, very_small_base_size)
}

#' Add Question List to Summary Sheet
#'
#' Helper function that adds question list section to summary sheet.
#'
#' @param wb Workbook object
#' @param all_results List, all question results
#' @param config List, configuration
#' @param styles List, style objects
#' @param start_row Integer, starting row number
#' @param total_column_name Character, name of total column
#' @param very_small_base_size Numeric, very small base threshold
#' @return Invisible NULL
add_question_list <- function(wb, all_results, config, styles, start_row,
                             total_column_name = "Total",
                             very_small_base_size = 10) {
  question_list_rows <- list(
    c("Question Code", "Question Text", "Variable Type", "Base (Total)", "Base Warning")
  )

  for (q_code in names(all_results)) {
    q_result <- all_results[[q_code]]

    total_key <- paste0("TOTAL::", total_column_name)
    base_info <- q_result$bases[[total_key]]

    if (config$apply_weighting) {
      total_base <- round(base_info$weighted, 0)
      eff_base <- round(base_info$effective, 0)
      base_display <- paste0(total_base, " (eff: ", eff_base, ")")
    } else {
      total_base <- base_info$unweighted
      eff_base <- total_base
      base_display <- as.character(total_base)
    }

    base_warning <- ""
    if (eff_base < very_small_base_size) {
      base_warning <- paste0("WARNING: Very small base (n<", very_small_base_size, ")")
    } else if (eff_base < config$significance_min_base) {
      base_warning <- paste0("CAUTION: Small base (n<", config$significance_min_base, ")")
    }

    filter_text <- if (!is.null(q_result$base_filter) &&
                      !is.na(q_result$base_filter) &&
                      q_result$base_filter != "") {
      paste0(" [Filter: ", q_result$base_filter, "]")
    } else {
      ""
    }

    question_list_rows[[length(question_list_rows) + 1]] <- c(
      q_result$question_code,
      paste0(q_result$question_text, filter_text),
      q_result$question_type,
      base_display,
      base_warning
    )
  }

  question_list_df <- as.data.frame(do.call(rbind, question_list_rows),
                                   stringsAsFactors = FALSE)
  names(question_list_df) <- question_list_df[1, ]
  question_list_df <- question_list_df[-1, ]

  openxlsx::writeData(wb, "Summary", "QUESTION LIST",
                     startRow = start_row, startCol = 1)
  openxlsx::addStyle(wb, "Summary", styles$section, rows = start_row,
                    cols = 1:5, gridExpand = TRUE)

  openxlsx::writeData(wb, "Summary", question_list_df,
                     startRow = start_row + 1, colNames = TRUE)
  openxlsx::addStyle(wb, "Summary", styles$header, rows = start_row + 1,
                    cols = 1:5, gridExpand = TRUE)

  for (i in seq_len(nrow(question_list_df))) {
    warning_text <- question_list_df[i, 5]
    if (!is.na(warning_text) && warning_text != "") {
      style <- if (grepl("WARNING", warning_text)) {
        styles$warning
      } else if (grepl("CAUTION", warning_text)) {
        styles$caution
      } else {
        NULL
      }

      if (!is.null(style)) {
        openxlsx::addStyle(wb, "Summary", style,
                          rows = start_row + 1 + i, cols = 1:5,
                          gridExpand = TRUE)
      }
    }
  }

  openxlsx::setColWidths(wb, "Summary", cols = 1:5,
                        widths = c(15, 50, 15, 20, 30))
}

# ==============================================================================
# ERROR LOG SHEET CREATION
# ==============================================================================

#' Write Error Log Sheet
#'
#' Creates error log sheet with any validation errors or warnings.
#'
#' @param wb Workbook object
#' @param error_log Data frame with error log (or NULL/empty)
#' @param styles List, style objects
#' @return Invisible NULL
#' @export
write_error_log_sheet <- function(wb, error_log, styles) {
  if (!is.null(error_log) && is.data.frame(error_log) && nrow(error_log) > 0) {
    openxlsx::addWorksheet(wb, "Error Log")
    openxlsx::writeData(wb, "Error Log", error_log, startRow = 1, colNames = TRUE)

    openxlsx::addStyle(wb, "Error Log", styles$header, rows = 1,
                      cols = 1:ncol(error_log), gridExpand = TRUE)

    for (i in seq_len(nrow(error_log))) {
      style <- switch(error_log$Severity[i],
        "Error" = styles$error,
        "Warning" = styles$warning,
        NULL
      )

      if (!is.null(style)) {
        openxlsx::addStyle(wb, "Error Log", style, rows = i + 1,
                          cols = 1:ncol(error_log), gridExpand = TRUE)
      }
    }

    openxlsx::setColWidths(wb, "Error Log", cols = 1:ncol(error_log), widths = "auto")
  } else {
    openxlsx::addWorksheet(wb, "Error Log")
    openxlsx::writeData(wb, "Error Log", "No errors or warnings.",
                       startRow = 1, startCol = 1)
  }

  invisible(NULL)
}

# ==============================================================================
# SAMPLE COMPOSITION SHEET
# ==============================================================================

# ==============================================================================
# SAMPLE COMPOSITION HELPERS (INTERNAL)
# ==============================================================================

#' Get banner variable label
#' @keywords internal
get_banner_variable_label <- function(banner_info, banner_idx, banner_code) {
  if ("BannerLabel" %in% names(banner_info$banner_questions)) {
    label <- banner_info$banner_questions$BannerLabel[banner_idx]
    if (!is.null(label) && !is.na(label) && label != "") {
      return(as.character(label))
    }
  }
  return(banner_code)
}

#' Find matching rows for banner category
#' @keywords internal
find_category_matches <- function(data, banner_code, cat_name, cat_options,
                                 is_boxcategory, question_info) {
  if (is_boxcategory) {
    # BoxCategory banner
    if (question_info$Variable_Type == "Multi_Mention") {
      num_cols <- suppressWarnings(as.numeric(question_info$Columns))
      if (!is.na(num_cols) && num_cols > 0) {
        banner_cols <- paste0(banner_code, "_", seq_len(num_cols))
        existing_cols <- banner_cols[banner_cols %in% names(data)]

        matching_rows <- Reduce(`|`, lapply(existing_cols, function(col) {
          Reduce(`|`, lapply(cat_options, function(opt) {
            safe_equal(data[[col]], opt) & !is.na(data[[col]])
          }))
        }))
      } else {
        matching_rows <- rep(FALSE, nrow(data))
      }
    } else {
      if (banner_code %in% names(data)) {
        matching_rows <- Reduce(`|`, lapply(cat_options, function(opt) {
          safe_equal(data[[banner_code]], opt) & !is.na(data[[banner_code]])
        }))
      } else {
        matching_rows <- rep(FALSE, nrow(data))
      }
    }
  } else {
    # Standard banner
    if (banner_code %in% names(data)) {
      matching_rows <- safe_equal(data[[banner_code]], cat_name) &
                      !is.na(data[[banner_code]])
    } else {
      matching_rows <- rep(FALSE, nrow(data))
    }
  }

  return(which(matching_rows))
}

#' Calculate composition statistics for a category
#' @keywords internal
calculate_composition_stats <- function(row_idx, data, master_weights, config) {
  comp_row <- list(
    Unweighted_n = length(row_idx),
    Unweighted_pct = if (nrow(data) > 0) {
      round(100 * length(row_idx) / nrow(data), 1)
    } else {
      NA_real_
    }
  )

  if (config$apply_weighting) {
    subset_weights <- master_weights[row_idx]
    valid_weights <- subset_weights[!is.na(subset_weights) & is.finite(subset_weights)]

    weighted_n <- sum(valid_weights, na.rm = TRUE)
    total_weight <- sum(master_weights[!is.na(master_weights) & is.finite(master_weights)], na.rm = TRUE)

    comp_row$Weighted_n <- round(weighted_n, 1)
    comp_row$Weighted_pct <- if (total_weight > 0) {
      round(100 * weighted_n / total_weight, 1)
    } else {
      NA_real_
    }
    comp_row$Effective_n <- calculate_effective_n(valid_weights)
  }

  return(comp_row)
}

#' Create Sample Composition Sheet
#'
#' Shows distribution of each banner variable across categories.
#' FIXED: Added survey_structure parameter to look up Variable_Type.
#'
#' @param wb Workbook object
#' @param data Survey data frame
#' @param banner_info Banner structure metadata
#' @param master_weights Weight vector
#' @param config Configuration list
#' @param styles Excel styles list
#' @param survey_structure Survey structure (for Variable_Type lookup)
#' @export
create_sample_composition_sheet <- function(wb, data, banner_info, master_weights,
                                           config, styles, survey_structure) {
  # Safety check
  if (is.null(banner_info$banner_questions) ||
      nrow(banner_info$banner_questions) == 0) {
    return(invisible(NULL))
  }

  tryCatch({
    openxlsx::addWorksheet(wb, "Sample Composition")

    current_row <- 1

    # Title
    openxlsx::writeData(wb, "Sample Composition", "SAMPLE COMPOSITION",
                       startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, "Sample Composition", styles$section,
                      rows = current_row, cols = 1:7, gridExpand = TRUE)
    current_row <- current_row + 2

    # Build composition data
    composition_rows <- list()

    for (banner_idx in seq_len(nrow(banner_info$banner_questions))) {
      banner_code <- banner_info$banner_questions$QuestionCode[banner_idx]
      banner_data <- banner_info$banner_info[[banner_code]]

      if (is.null(banner_data)) next

      # Look up question info for Variable_Type
      question_info <- survey_structure$questions[
        survey_structure$questions$QuestionCode == banner_code,
      ]

      if (nrow(question_info) == 0) next
      question_info <- question_info[1, ]

      # Get variable label (delegated to helper)
      var_label <- get_banner_variable_label(banner_info, banner_idx, banner_code)

      # Process each category
      for (cat_idx in seq_along(banner_data$columns)) {
        cat_name <- banner_data$columns[cat_idx]
        cat_options <- if (banner_data$is_boxcategory) {
          banner_data$boxcat_groups[[cat_name]]
        } else {
          NULL
        }

        # Find matching rows (delegated to helper)
        row_idx <- find_category_matches(
          data, banner_code, cat_name, cat_options,
          banner_data$is_boxcategory, question_info
        )

        # Calculate composition stats (delegated to helper)
        comp_stats <- calculate_composition_stats(row_idx, data, master_weights, config)

        # Combine with Variable and Category labels
        comp_row <- c(
          list(
            Variable = if (cat_idx == 1) var_label else "",
            Category = cat_name
          ),
          comp_stats
        )

        composition_rows[[length(composition_rows) + 1]] <- comp_row
      }
    }

    if (length(composition_rows) == 0) {
      return(invisible(NULL))
    }

    # Convert to data frame
    composition_df <- do.call(rbind, lapply(composition_rows, as.data.frame,
                                            stringsAsFactors = FALSE))

    # Write headers
    header_cols <- c("Variable", "Category", "Unweighted n", "Unweighted %")
    if (config$apply_weighting) {
      header_cols <- c(header_cols, "Weighted n", "Weighted %", "Effective n")
    }

    openxlsx::writeData(wb, "Sample Composition",
                       matrix(header_cols, nrow = 1),
                       startRow = current_row, colNames = FALSE)
    openxlsx::addStyle(wb, "Sample Composition", styles$header,
                      rows = current_row, cols = 1:length(header_cols),
                      gridExpand = TRUE)
    current_row <- current_row + 1

    # Write data
    openxlsx::writeData(wb, "Sample Composition", composition_df,
                       startRow = current_row, colNames = FALSE)

    # Alternating row colors
    for (i in seq_len(nrow(composition_df))) {
      if (i %% 2 == 0) {
        openxlsx::addStyle(wb, "Sample Composition",
                          openxlsx::createStyle(fgFill = "#F9F9F9"),
                          rows = current_row + i - 1,
                          cols = 1:ncol(composition_df),
                          gridExpand = TRUE)
      }
    }

    # Column widths
    openxlsx::setColWidths(wb, "Sample Composition",
                          cols = 1:ncol(composition_df),
                          widths = c(25, 25, rep(15, ncol(composition_df) - 2)))

  }, error = function(e) {
    warning(sprintf("Sample composition sheet creation failed: %s", conditionMessage(e)))
  })

  invisible(NULL)
}

# ==============================================================================
# MODULE INFO
# ==============================================================================

#' Get Excel Writer Module Information
#'
#' Returns metadata about the excel_writer module.
#'
#' @return List with module information
#' @export
get_excel_writer_info <- function() {
  list(
    module = "excel_writer",
    version = "1.0.0",
    date = "2025-10-25",
    description = "Excel workbook writer for crosstab results",
    functions = c(
      "write_crosstab_workbook",
      "create_excel_styles",
      "write_banner_headers",
      "write_question_table",
      "write_base_rows",
      "get_row_style",
      "get_excel_writer_info"
    ),
    dependencies = c(
      "openxlsx",
      "utilities.R"
    )
  )
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs excel_writer module loaded")

# ==============================================================================
# END OF MODULE 13: EXCEL_WRITER.R
# ==============================================================================
