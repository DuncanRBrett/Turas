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
#   - /modules/shared/lib/ (formatting, validation, config utilities)
#
# VERSION: 1.2.0 - Uses consolidated shared utilities
# DATE: 2025-12-13
# CHANGES: Now uses /modules/shared/lib/ for consistent utilities
# ==============================================================================

# Require openxlsx
if (!requireNamespace("openxlsx", quietly = TRUE)) {
  tabs_refuse(
    code = "PKG_MISSING_DEPENDENCY",
    title = "Missing Required Package: openxlsx",
    problem = "The 'openxlsx' package is not installed. This package is required for Excel output.",
    why_it_matters = "Cannot write crosstab results to Excel format without openxlsx. The excel_writer module cannot function.",
    how_to_fix = c(
      "Install the package: install.packages('openxlsx')",
      "Then reload the Tabs module"
    )
  )
}

# Load shared utilities from consolidated location
# Only load if not already available (avoid re-sourcing)
if (!exists("find_turas_root", mode = "function")) {
  # Find Turas root by looking for marker files
  .find_root <- function() {
    current_dir <- getwd()
    while (current_dir != dirname(current_dir)) {
      has_launch <- file.exists(file.path(current_dir, "launch_turas.R"))
      has_modules <- dir.exists(file.path(current_dir, "modules"))
      if (has_launch || has_modules) {
        return(current_dir)
      }
      current_dir <- dirname(current_dir)
    }
    tabs_refuse(
      code = "ENV_TURAS_ROOT_NOT_FOUND",
      title = "Cannot Locate Turas Root Directory",
      problem = "Could not find Turas root directory by searching for launch_turas.R or modules/ directory.",
      why_it_matters = "Cannot load shared utilities without locating the Turas root. The excel_writer module cannot initialize.",
      how_to_fix = c(
        "Ensure you are running from within a Turas project directory structure",
        "Verify that launch_turas.R exists in the Turas root",
        "Check that the modules/ directory exists",
        "Run from the correct working directory"
      )
    )
  }

  .turas_root <- .find_root()
  .shared_lib_path <- file.path(.turas_root, "modules", "shared", "lib")

  source(file.path(.shared_lib_path, "validation_utils.R"), local = FALSE)
  source(file.path(.shared_lib_path, "config_utils.R"), local = FALSE)
  source(file.path(.shared_lib_path, "formatting_utils.R"), local = FALSE)

  rm(.turas_root, .shared_lib_path, .find_root)
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
#' NOTE (Phase 2 Update): This function now uses shared/formatting.R
#' for number format generation. This ensures consistent decimal separator
#' handling across all TURAS modules.
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

  # Phase 2 Update: Use shared formatting module
  # This ensures consistent number formatting across Tabs and Tracker
  fmt_percent <- create_excel_number_format(decimal_places_percent, decimal_separator)
  fmt_rating <- create_excel_number_format(decimal_places_ratings, decimal_separator)
  fmt_index <- create_excel_number_format(decimal_places_index, decimal_separator)
  fmt_numeric <- create_excel_number_format(decimal_places_numeric, decimal_separator)

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
      numFmt = fmt_percent
    ),

    row_pct = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "#595959",
      halign = "left", valign = "center",
      numFmt = fmt_percent
    ),
    
    sig = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center"
    ),
    
    rating_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_rating
    ),

    numeric_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_numeric
    ),

    index_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_index
    ),

    score_style = openxlsx::createStyle(
      fontSize = 12, fontName = "Aptos", fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_percent
    ),
    
    row_label = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos",
      halign = "left", valign = "center"
    ),

    stddev_style = openxlsx::createStyle(
      fontSize = 11, fontName = "Aptos", fontColour = "#595959",
      halign = "center", valign = "center", fgFill = "#F2F2F2",
      numFmt = fmt_rating
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

  # Safe config value extraction
  apply_weighting <- !is.null(config$apply_weighting) &&
                     length(config$apply_weighting) > 0 &&
                     config$apply_weighting

  enable_sig_testing <- !is.null(config$enable_significance_testing) &&
                        length(config$enable_significance_testing) > 0 &&
                        config$enable_significance_testing

  show_frequency <- !is.null(config$show_frequency) &&
                    length(config$show_frequency) > 0 &&
                    config$show_frequency

  show_percent_column <- !is.null(config$show_percent_column) &&
                         length(config$show_percent_column) > 0 &&
                         config$show_percent_column

  show_percent_row <- !is.null(config$show_percent_row) &&
                      length(config$show_percent_row) > 0 &&
                      config$show_percent_row

  zero_division_as_blank <- !is.null(config$zero_division_as_blank) &&
                            length(config$zero_division_as_blank) > 0 &&
                            config$zero_division_as_blank

  bonf_corr <- !is.null(config$bonferroni_correction) &&
               length(config$bonferroni_correction) > 0 &&
               config$bonferroni_correction

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
    c("Weighting Applied", if (apply_weighting) "YES" else "NO"),
    c("Weight Variable", if (apply_weighting && !is.null(config$weight_variable)) config$weight_variable else "N/A"),
    c("Effective Sample Size", as.character(project_info$effective_n)),
    c("", ""),
    c("SIGNIFICANCE TESTING", ""),
    c("Enabled", if (enable_sig_testing) "YES" else "NO"),
    c("Alpha (p-value threshold)", if (enable_sig_testing && !is.null(config$alpha))
      sprintf("%.3f", config$alpha) else "N/A"),
    c("Minimum Base Size", if (enable_sig_testing && !is.null(config$significance_min_base))
      as.character(config$significance_min_base) else "N/A"),
    c("Bonferroni Correction", if (enable_sig_testing && bonf_corr) "YES" else "NO"),
    c("", ""),
    c("DISPLAY SETTINGS", ""),
    c("Show Frequency", if (show_frequency) "YES" else "NO"),
    c("Show Column %", if (show_percent_column) "YES" else "NO"),
    c("Show Row %", if (show_percent_row) "YES" else "NO"),
    c("Zero Division Display", if (zero_division_as_blank) "Blank" else "Zero"),
    c("Decimal Places (Percent)", if (!is.null(config$decimal_places_percent)) as.character(config$decimal_places_percent) else "1"),
    c("Decimal Places (Ratings)", if (!is.null(config$decimal_places_ratings)) as.character(config$decimal_places_ratings) else "1"),
    c("Decimal Places (Index)", if (!is.null(config$decimal_places_index)) as.character(config$decimal_places_index) else "1"),
    c("Decimal Separator", if (!is.null(config$decimal_separator)) config$decimal_separator else "."),
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
  # Safe config extraction
  apply_weighting <- !is.null(config$apply_weighting) &&
                     length(config$apply_weighting) > 0 &&
                     config$apply_weighting

  sig_min_base <- if (!is.null(config$significance_min_base) &&
                      length(config$significance_min_base) > 0) {
    config$significance_min_base
  } else {
    30  # Default
  }

  question_list_rows <- list(
    c("Question Code", "Question Text", "Variable Type", "Base (Total)", "Base Warning")
  )

  for (q_code in names(all_results)) {
    q_result <- all_results[[q_code]]

    total_key <- paste0("TOTAL::", total_column_name)
    base_info <- if (!is.null(q_result$bases)) {
      q_result$bases[[total_key]]
    } else {
      NULL
    }

    if (!is.null(base_info)) {
      if (apply_weighting) {
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
      } else if (eff_base < sig_min_base) {
        base_warning <- paste0("CAUTION: Small base (n<", sig_min_base, ")")
      }
    } else {
      # No base info available (shouldn't happen, but handle gracefully)
      base_display <- "N/A"
      base_warning <- ""
      eff_base <- 0
    }

    filter_text <- if (!is.null(q_result$base_filter) &&
                      length(q_result$base_filter) > 0 &&
                      !is.na(q_result$base_filter) &&
                      nchar(trimws(q_result$base_filter)) > 0) {
      paste0(" [Filter: ", q_result$base_filter, "]")
    } else {
      ""
    }

    # Safe extraction of question fields
    q_code_display <- if (!is.null(q_result$question_code) &&
                          length(q_result$question_code) > 0) {
      as.character(q_result$question_code)
    } else {
      q_code
    }

    q_text <- if (!is.null(q_result$question_text) &&
                  length(q_result$question_text) > 0) {
      as.character(q_result$question_text)
    } else {
      ""
    }

    q_type <- if (!is.null(q_result$question_type) &&
                  length(q_result$question_type) > 0) {
      as.character(q_result$question_type)
    } else {
      "Unknown"
    }

    question_list_rows[[length(question_list_rows) + 1]] <- c(
      q_code_display,
      paste0(q_text, filter_text),
      q_type,
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

    # Safe warning text check
    has_warning <- !is.null(warning_text) &&
                   length(warning_text) > 0 &&
                   !is.na(warning_text) &&
                   nchar(trimws(as.character(warning_text))) > 0

    if (has_warning) {
      warning_text_str <- as.character(warning_text)

      style <- if (grepl("WARNING", warning_text_str)) {
        styles$warning
      } else if (grepl("CAUTION", warning_text_str)) {
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
#' @param data Survey data frame
#' @param banner_code Banner question code
#' @param cat_name Category name (DisplayText for display)
#' @param cat_options BoxCategory options to match (OptionText values)
#' @param is_boxcategory Whether this is a box/category banner
#' @param question_info Question information
#' @param option_text OptionText value for matching (for standard banners)
#' @keywords internal
find_category_matches <- function(data, banner_code, cat_name, cat_options,
                                 is_boxcategory, question_info, option_text = NULL) {
  if (is_boxcategory) {
    # BoxCategory banner
    if (question_info$Variable_Type == "Multi_Mention") {
      num_cols <- suppressWarnings(as.numeric(question_info$Columns))
      if (!is.na(num_cols) && num_cols > 0) {
        banner_cols <- paste0(banner_code, "_", seq_len(num_cols))
        existing_cols <- banner_cols[banner_cols %in% names(data)]

        if (length(existing_cols) == 0 || is.null(cat_options) || length(cat_options) == 0) {
          matching_rows <- rep(FALSE, nrow(data))
        } else {
          matching_rows <- Reduce(`|`, lapply(existing_cols, function(col) {
            Reduce(`|`, lapply(cat_options, function(opt) {
              safe_equal(data[[col]], opt) & !is.na(data[[col]])
            }))
          }))
        }
      } else {
        matching_rows <- rep(FALSE, nrow(data))
      }
    } else {
      if (banner_code %in% names(data) && !is.null(cat_options) && length(cat_options) > 0) {
        matching_rows <- Reduce(`|`, lapply(cat_options, function(opt) {
          safe_equal(data[[banner_code]], opt) & !is.na(data[[banner_code]])
        }))
      } else {
        matching_rows <- rep(FALSE, nrow(data))
      }
    }
  } else {
    # Standard banner - use option_text (OptionText from survey structure) for matching
    # V10.1 FIX: Previously used cat_name (DisplayText) which doesn't match data values
    match_value <- if (!is.null(option_text) && nchar(trimws(option_text)) > 0) {
      option_text
    } else {
      cat_name  # Fallback to cat_name if option_text not provided
    }

    if (banner_code %in% names(data)) {
      matching_rows <- safe_equal(data[[banner_code]], match_value) &
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

        # V10.1 FIX: Get OptionText for standard banner matching
        # DisplayText is used for display, but data contains OptionText values
        option_text <- NULL
        if (!banner_data$is_boxcategory && !is.null(banner_data$options)) {
          # Find the option matching this display text
          opt_idx <- which(banner_data$options$DisplayText == cat_name)
          if (length(opt_idx) > 0) {
            option_text <- banner_data$options$OptionText[opt_idx[1]]
          }
        }

        # Find matching rows (delegated to helper)
        row_idx <- find_category_matches(
          data, banner_code, cat_name, cat_options,
          banner_data$is_boxcategory, question_info, option_text
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
# INDEX SUMMARY SHEET WRITER (COMPOSITE METRICS FEATURE)
# ==============================================================================

#' Write Index Summary Sheet
#'
#' Write formatted Index_Summary sheet to Excel workbook
#'
#' @param wb Workbook object
#' @param summary_table Data frame with summary metrics
#' @param banner_info Banner structure
#' @param config Configuration list
#' @param styles Styles list
#' @return Invisible NULL (modifies workbook by reference)
#' @export
write_index_summary_sheet <- function(wb, summary_table, banner_info,
                                       config, styles, all_results = NULL) {

  if (is.null(summary_table) || nrow(summary_table) == 0) {
    return(invisible(NULL))
  }

  # Extract base sizes from first question result if banner_info$base_sizes is NULL
  if (is.null(banner_info$base_sizes) && !is.null(all_results) && length(all_results) > 0) {
    # Get first result that has bases
    for (result in all_results) {
      if (!is.null(result$bases)) {
        banner_info$base_sizes <- result$bases
        break
      }
    }
  }

  # Create sheet
  openxlsx::addWorksheet(wb, "Index_Summary")

  current_row <- 1

  # Title style
  title_style <- openxlsx::createStyle(
    fontSize = 14,
    textDecoration = "bold",
    halign = "left"
  )

  # Section header style
  section_style <- openxlsx::createStyle(
    fontSize = 11,
    textDecoration = "bold",
    fgFill = "#E8E8E8",
    border = "TopBottom"
  )

  # Composite row style
  composite_style <- openxlsx::createStyle(
    fontSize = 10,
    fgFill = "#FFF8DC",
    fontName = "Calibri"
  )

  # Metric style
  metric_style <- openxlsx::createStyle(
    fontSize = 10,
    halign = "left"
  )

  # Data cell style - use General format to display values as-is
  # Values are already formatted correctly when extracted from crosstab results
  data_style <- openxlsx::createStyle(
    fontSize = 10,
    halign = "right",
    numFmt = "General"
  )

  # Write title section
  openxlsx::writeData(wb, "Index_Summary", "INDEX & RATING SUMMARY",
                      startCol = 1, startRow = current_row)
  openxlsx::addStyle(wb, "Index_Summary", title_style,
                     rows = current_row, cols = 1, gridExpand = FALSE)
  current_row <- current_row + 2

  # Write metadata
  project_name <- if (!is.null(config$project_name) && length(config$project_name) > 0) {
    config$project_name
  } else {
    "Survey Analysis"
  }
  openxlsx::writeData(wb, "Index_Summary",
                      paste("Survey:", project_name),
                      startRow = current_row)
  current_row <- current_row + 1

  base_desc <- if (!is.null(banner_info$base_description) &&
                   length(banner_info$base_description) > 0) {
    banner_info$base_description
  } else {
    "All Respondents"
  }
  openxlsx::writeData(wb, "Index_Summary",
                      paste("Base:", base_desc),
                      startRow = current_row)
  current_row <- current_row + 2

  # Write column headers
  internal_keys <- banner_info$internal_keys

  # Safe extraction of column labels
  column_labels <- if (!is.null(banner_info$column_labels) &&
                       length(banner_info$column_labels) > 0) {
    banner_info$column_labels
  } else {
    internal_keys  # Fallback to internal keys
  }

  # Write banner labels row (above column options)
  # This shows the BannerLabel for each banner group
  if (!is.null(banner_info$banner_headers) && nrow(banner_info$banner_headers) > 0) {
    # Create banner label row with empty first cell for "Metric" column
    banner_label_row <- rep("", length(column_labels) + 1)

    for (i in seq_len(nrow(banner_info$banner_headers))) {
      start_col <- banner_info$banner_headers$start_col[i]
      label <- banner_info$banner_headers$label[i]

      # Adjust for the "Metric" column offset (column 1)
      # banner_headers start_col is 2-based (after Total), add 1 for Metric column
      col_idx <- start_col + 1  # +1 for Metric column
      if (col_idx <= length(banner_label_row)) {
        banner_label_row[col_idx] <- label
      }
    }

    openxlsx::writeData(wb, "Index_Summary", t(banner_label_row),
                        startCol = 1, startRow = current_row, colNames = FALSE)
    openxlsx::addStyle(wb, "Index_Summary", styles$banner,
                       rows = current_row, cols = 1:length(banner_label_row),
                       gridExpand = TRUE)
    current_row <- current_row + 1
  }

  # Write column options row
  headers <- c("Metric", column_labels)

  openxlsx::writeData(wb, "Index_Summary", t(headers),
                      startCol = 1, startRow = current_row, colNames = FALSE)
  openxlsx::addStyle(wb, "Index_Summary", styles$header,
                     rows = current_row, cols = 1:length(headers),
                     gridExpand = TRUE)
  current_row <- current_row + 1

  # Write data rows
  for (i in 1:nrow(summary_table)) {
    row_data <- summary_table[i, ]

    # Determine style based on row type
    # Safe extraction of StyleHint
    style_hint <- if ("StyleHint" %in% names(row_data) &&
                      !is.null(row_data$StyleHint) &&
                      length(row_data$StyleHint) > 0) {
      as.character(row_data$StyleHint[1])
    } else {
      "Normal"
    }

    if (!is.na(style_hint) && style_hint == "SectionHeader") {
      row_style <- section_style
      is_section <- TRUE
    } else if (!is.na(style_hint) && style_hint == "Composite") {
      row_style <- composite_style
      is_section <- FALSE
    } else {
      row_style <- metric_style
      is_section <- FALSE
    }

    # Write row label
    # Safe extraction of RowLabel
    row_label <- if ("RowLabel" %in% names(row_data) &&
                     !is.null(row_data$RowLabel) &&
                     length(row_data$RowLabel) > 0) {
      as.character(row_data$RowLabel[1])
    } else {
      ""
    }

    openxlsx::writeData(wb, "Index_Summary", row_label,
                        startCol = 1, startRow = current_row)
    openxlsx::addStyle(wb, "Index_Summary", row_style,
                       rows = current_row, cols = 1, gridExpand = FALSE)

    # Write data values (skip if section header)
    if (!is_section) {
      for (j in seq_along(internal_keys)) {
        key <- internal_keys[j]

        if (key %in% names(row_data)) {
          value <- row_data[[key]]

          # Safe value extraction and conversion to numeric
          if (is.null(value) || length(value) == 0) {
            value <- ""
          } else {
            # Extract single value and convert to character first for safety
            value <- as.character(value[1])

            # Handle NA values
            if (is.na(value) || value == "NA") {
              value <- ""
            } else if (value != "") {
              # Try to convert to numeric (so Excel style formatting applies)
              has_letters <- grepl("[a-zA-Z]", value)
              if (!is.na(has_letters) && !has_letters) {
                numeric_value <- suppressWarnings(as.numeric(gsub(",", ".", value)))
                if (!is.na(numeric_value)) {
                  value <- numeric_value
                }
                # else keep as character string
              }
              # else keep as character string with letters
            }
          }

          openxlsx::writeData(wb, "Index_Summary", value,
                              startCol = j + 1, startRow = current_row)
          openxlsx::addStyle(wb, "Index_Summary", data_style,
                             rows = current_row, cols = j + 1,
                             gridExpand = FALSE)
        }
      }
    } else {
      # Section header - apply style across row
      openxlsx::addStyle(wb, "Index_Summary", section_style,
                         rows = current_row, cols = 1:length(headers),
                         gridExpand = TRUE)
    }

    current_row <- current_row + 1
  }

  # Add base sizes at bottom if enabled
  show_base <- if ("index_summary_show_base_sizes" %in% names(config)) {
    isTRUE(config$index_summary_show_base_sizes) ||
      toupper(trimws(as.character(config$index_summary_show_base_sizes))) == "Y"
  } else {
    TRUE  # Default
  }

  if (show_base) {
    current_row <- current_row + 1

    # Write "Base sizes:" label
    openxlsx::writeData(wb, "Index_Summary", "Base sizes:",
                        startCol = 1, startRow = current_row)
    openxlsx::addStyle(wb, "Index_Summary", metric_style,
                       rows = current_row, cols = 1, gridExpand = FALSE)
    current_row <- current_row + 1

    # Write unweighted n
    openxlsx::writeData(wb, "Index_Summary", "Unweighted n:",
                        startCol = 1, startRow = current_row)

    for (j in seq_along(internal_keys)) {
      key <- internal_keys[j]
      if (!is.null(banner_info$base_sizes[[key]])) {
        n <- banner_info$base_sizes[[key]]$unweighted
        openxlsx::writeData(wb, "Index_Summary", n,
                            startCol = j + 1, startRow = current_row)
      }
    }

    # Write weighted n (if applicable)
    apply_weighting <- !is.null(config$apply_weighting) &&
                       length(config$apply_weighting) > 0 &&
                       config$apply_weighting

    if (apply_weighting) {
      current_row <- current_row + 1
      openxlsx::writeData(wb, "Index_Summary", "Weighted n:",
                          startCol = 1, startRow = current_row)

      for (j in seq_along(internal_keys)) {
        key <- internal_keys[j]
        if (!is.null(banner_info$base_sizes[[key]])) {
          n <- banner_info$base_sizes[[key]]$weighted
          openxlsx::writeData(wb, "Index_Summary", round(n, 0),
                              startCol = j + 1, startRow = current_row)
        }
      }
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Index_Summary", cols = 1, widths = 40)
  openxlsx::setColWidths(wb, "Index_Summary",
                         cols = 2:(length(headers)), widths = 12)

  return(invisible(NULL))
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs excel_writer module loaded")

# ==============================================================================
# END OF MODULE 13: EXCEL_WRITER.R
# ==============================================================================
