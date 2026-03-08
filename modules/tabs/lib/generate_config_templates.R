# ==============================================================================
# GENERATE_CONFIG_TEMPLATES.R - TURAS Tabs Module
# ==============================================================================
# Creates professional, hardened Excel config templates with:
#   - Data validation (dropdown lists) for all option fields
#   - Visual formatting (branded colours, section grouping)
#   - Help text descriptors for every field
#   - Required/Optional markers
#   - Protected non-editable areas (headers, descriptors)
#   - Every permutation and option documented
#
# USAGE:
#   source("modules/tabs/lib/generate_config_templates.R")
#   generate_crosstab_config_template("path/to/output/Crosstab_Config.xlsx")
#   generate_survey_structure_template("path/to/output/Survey_Structure.xlsx")
#   # Or generate both:
#   generate_all_templates("path/to/output/")
#
# ==============================================================================

library(openxlsx)

# ==============================================================================
# COLOUR PALETTE & STYLE DEFINITIONS
# ==============================================================================

# Brand colours
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

# --- Reusable style factories ---

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


# ==============================================================================
# HELPER: Write a settings sheet with sections, help text, and dropdowns
# ==============================================================================

#' Write a formatted settings sheet
#'
#' @param wb Workbook object
#' @param sheet_name Name for the sheet
#' @param settings_def List of section definitions (see internal format)
#' @param title Sheet title
#' @param subtitle Sheet subtitle
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

#' Write a formatted table sheet (Questions, Options, Selection, etc.)
#'
#' @param wb Workbook object
#' @param sheet_name Sheet name
#' @param columns_def List of column definitions
#' @param title Sheet title
#' @param subtitle Sheet subtitle
#' @param example_rows Optional list of example data rows
#' @param num_blank_rows Number of blank rows to format for input (default 50)
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

  # Help row (descriptions under headers)
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
      # Style example rows
      addStyle(wb, sheet_name,
               createStyle(fontName = "Calibri", fontSize = 10,
                           fgFill = "#E3F2FD",
                           border = "TopBottomLeftRight", borderColour = .TPL_BORDER,
                           halign = "left", valign = "center",
                           fontColour = "#37474F"),
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
  }

  # Freeze panes
  freezePane(wb, sheet_name, firstActiveRow = data_start, firstActiveCol = 1)

  invisible(NULL)
}


# ==============================================================================
# CROSSTAB CONFIG TEMPLATE
# ==============================================================================

#' Generate a Professional Crosstab Config Template
#'
#' Creates a hardened, professionally formatted Crosstab_Config.xlsx with
#' dropdown validation, help text, and complete field coverage.
#'
#' @param output_path Path for the output Excel file
#' @param structure_file Default structure file path to pre-fill (default: "Survey_Structure.xlsx")
#' @return Invisible path to created file
#' @export
generate_crosstab_config_template <- function(output_path,
                                               structure_file = "Survey_Structure.xlsx") {

  wb <- createWorkbook()

  # --- SHEET 1: Settings ---
  settings_def <- list(
    # ---- FILE PATHS ----
    list(
      section_name = "FILE PATHS & OUTPUT",
      fields = list(
        list(name = "structure_file", default = structure_file, required = TRUE,
             description = "Path to Survey_Structure.xlsx (relative to this config file)",
             valid_values_text = "File path ending in .xlsx"),
        list(name = "output_subfolder", default = "Output", required = TRUE,
             description = "Folder name for output files. Created automatically if it doesn't exist.",
             valid_values_text = "Any folder name (no special chars)"),
        list(name = "output_filename", default = "Crosstabs.xlsx", required = TRUE,
             description = "Name of the output Excel workbook.",
             valid_values_text = "Filename ending in .xlsx"),
        list(name = "output_format", default = "xlsx", required = TRUE,
             description = "Output file format: Excel workbook or separate CSV files.",
             valid_values_text = "xlsx or csv",
             dropdown = c("xlsx", "csv"))
      )
    ),

    # ---- WEIGHTING ----
    list(
      section_name = "WEIGHTING",
      fields = list(
        list(name = "apply_weighting", default = "FALSE", required = TRUE,
             description = "Apply sample weights to all calculations. Set to TRUE if your data has a weight column.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "weight_variable", default = "", required = FALSE,
             description = "Column name in your data that contains weights. Required if apply_weighting = TRUE.",
             valid_values_text = "Exact column name from data file"),
        list(name = "show_unweighted_n", default = "TRUE", required = TRUE,
             description = "Show actual respondent count (unweighted N) alongside weighted results.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "show_effective_n", default = "TRUE", required = TRUE,
             description = "Show effective sample size (accounts for weighting design effect).",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "weight_label", default = "Weighted", required = TRUE,
             description = "Label displayed for weighted count rows in output tables.",
             valid_values_text = "Any descriptive text"),
        list(name = "weight_na_threshold", default = 10, required = TRUE,
             description = "Maximum % of missing weight values before a warning is issued.",
             valid_values_text = "0 to 100 (percentage)",
             integer_range = c(0, 100)),
        list(name = "weight_zero_threshold", default = 5, required = TRUE,
             description = "Maximum % of zero weight values before a warning is issued.",
             valid_values_text = "0 to 100 (percentage)",
             integer_range = c(0, 100)),
        list(name = "weight_deff_warning", default = 3, required = TRUE,
             description = "Design Effect threshold: warn if DEFF exceeds this value (high = low efficiency).",
             valid_values_text = "1 to 10 (typical: 2-3)",
             integer_range = c(1, 10))
      )
    ),

    # ---- DISPLAY OPTIONS ----
    list(
      section_name = "DISPLAY OPTIONS",
      fields = list(
        list(name = "show_frequency", default = "TRUE", required = TRUE,
             description = "Show raw counts (frequencies) in crosstab tables.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "show_percent_column", default = "TRUE", required = TRUE,
             description = "Show column percentages (% within each banner group). This is the standard view.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "show_percent_row", default = "FALSE", required = TRUE,
             description = "Show row percentages (% across banner groups for each option).",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "zero_division_as_blank", default = "TRUE", required = TRUE,
             description = "When base size is zero: show blank cell (TRUE) or display 0 (FALSE).",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "show_net_positive", default = "TRUE", required = TRUE,
             description = "Show NET POSITIVE row for Likert-type questions (top box minus bottom box).",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "show_standard_deviation", default = "FALSE", required = FALSE,
             description = "Show standard deviation for Rating/Likert mean scores.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "show_charts", default = "FALSE", required = TRUE,
             description = "Include inline SVG charts in HTML report output.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE"))
      )
    ),

    # ---- DECIMAL PLACES ----
    list(
      section_name = "DECIMAL PLACES",
      fields = list(
        list(name = "decimal_separator", default = ".", required = TRUE,
             description = "Character used as decimal separator in output. Period (.) = 8.2, Comma (,) = 8,2.",
             valid_values_text = ". or ,",
             dropdown = c(".", ",")),
        list(name = "decimal_places_percent", default = 0, required = TRUE,
             description = "Number of decimal places for percentage values (e.g., 0 = 45%, 1 = 45.3%).",
             valid_values_text = "0 to 4",
             integer_range = c(0, 4)),
        list(name = "decimal_places_ratings", default = 1, required = TRUE,
             description = "Number of decimal places for Rating question means (e.g., 1 = 7.3).",
             valid_values_text = "0 to 4",
             integer_range = c(0, 4)),
        list(name = "decimal_places_index", default = 1, required = TRUE,
             description = "Number of decimal places for Index/composite scores.",
             valid_values_text = "0 to 4",
             integer_range = c(0, 4)),
        list(name = "decimal_places_numeric", default = 1, required = TRUE,
             description = "Number of decimal places for Numeric question statistics (mean, median).",
             valid_values_text = "0 to 4",
             integer_range = c(0, 4))
      )
    ),

    # ---- BOX CATEGORY ----
    list(
      section_name = "BOX CATEGORY DISPLAY",
      fields = list(
        list(name = "boxcategory_frequency", default = "FALSE", required = TRUE,
             description = "Show raw counts in BoxCategory summary rows (e.g., Top 2 Box count).",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "boxcategory_percent_column", default = "TRUE", required = TRUE,
             description = "Show column percentages in BoxCategory summary rows.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "boxcategory_percent_row", default = "FALSE", required = TRUE,
             description = "Show row percentages in BoxCategory summary rows.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE"))
      )
    ),

    # ---- SIGNIFICANCE TESTING ----
    list(
      section_name = "SIGNIFICANCE TESTING",
      fields = list(
        list(name = "enable_significance_testing", default = "TRUE", required = TRUE,
             description = "Run statistical significance tests comparing banner groups. Results shown as letter codes.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "alpha", default = 0.05, required = TRUE,
             description = "Significance level: 0.05 = 95% confidence, 0.01 = 99% confidence, 0.10 = 90% confidence.",
             valid_values_text = "0.001 to 0.50 (typical: 0.05)",
             numeric_range = c(0.001, 0.50)),
        list(name = "significance_min_base", default = 30, required = TRUE,
             description = "Minimum sample size (base) required for significance testing. Groups below this are skipped.",
             valid_values_text = "1 to 1000 (typical: 30)",
             integer_range = c(1, 1000)),
        list(name = "bonferroni_correction", default = "TRUE", required = TRUE,
             description = "Apply Bonferroni correction to adjust for multiple comparisons (reduces false positives).",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "enable_chi_square", default = "FALSE", required = FALSE,
             description = "Run chi-square test of independence for each crosstab table.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "test_net_differences", default = "FALSE", required = FALSE,
             description = "Test significance of NET POSITIVE differences across banner groups.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE"))
      )
    ),

    # ---- NUMERIC QUESTIONS ----
    list(
      section_name = "NUMERIC QUESTION SETTINGS",
      fields = list(
        list(name = "show_numeric_median", default = "FALSE", required = TRUE,
             description = "Show median for Numeric-type questions (unweighted data only).",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "show_numeric_mode", default = "FALSE", required = TRUE,
             description = "Show mode (most frequent value) for Numeric-type questions (unweighted only).",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "show_numeric_outliers", default = "TRUE", required = TRUE,
             description = "Report outlier counts for Numeric-type questions.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "exclude_outliers_from_stats", default = "FALSE", required = TRUE,
             description = "Remove outliers before calculating mean/SD for Numeric questions.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "outlier_method", default = "IQR", required = TRUE,
             description = "Method for detecting outliers. IQR = 1.5 x interquartile range (Tukey's method).",
             valid_values_text = "IQR",
             dropdown = c("IQR"))
      )
    ),

    # ---- INDEX SUMMARY ----
    list(
      section_name = "INDEX SUMMARY SHEET",
      fields = list(
        list(name = "create_index_summary", default = "Y", required = TRUE,
             description = "Create an Index_Summary sheet showing all composite and index scores in one table.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "index_summary_show_sections", default = "Y", required = TRUE,
             description = "Group composites by their SectionLabel in the Index Summary.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "index_summary_show_base_sizes", default = "Y", required = TRUE,
             description = "Display base sizes (N) in the Index Summary sheet.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "index_summary_show_composites", default = "Y", required = TRUE,
             description = "Include composite metric scores in the Index Summary.",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "index_summary_decimal_places", default = 1, required = TRUE,
             description = "Number of decimal places in the Index Summary sheet.",
             valid_values_text = "0 to 3",
             integer_range = c(0, 3))
      )
    ),

    # ---- SAMPLE COMPOSITION ----
    list(
      section_name = "SAMPLE COMPOSITION",
      fields = list(
        list(name = "create_sample_composition", default = "FALSE", required = FALSE,
             description = "Create a Sample_Composition sheet showing demographic breakdowns of the sample.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE"))
      )
    ),

    # ---- PERFORMANCE ----
    list(
      section_name = "PERFORMANCE",
      fields = list(
        list(name = "enable_checkpointing", default = "TRUE", required = TRUE,
             description = "Save progress during long analyses. Allows resuming if interrupted.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE"))
      )
    ),

    # ---- SUMMARY DASHBOARD ----
    list(
      section_name = "SUMMARY DASHBOARD",
      fields = list(
        list(name = "include_summary", default = "TRUE", required = TRUE,
             description = "Include a visual summary dashboard in HTML report with gauge charts.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "fieldwork_dates", default = "", required = FALSE,
             description = "Fieldwork dates for documentation (displayed on dashboard). Any text format.",
             valid_values_text = "e.g. January - March 2025"),
        list(name = "dashboard_metrics", default = "NET POSITIVE", required = TRUE,
             description = "Primary metric type to display in dashboard gauges.",
             valid_values_text = "NET POSITIVE or custom",
             dropdown = c("NET POSITIVE")),
        list(name = "dashboard_sort_gauges", default = "desc", required = TRUE,
             description = "Sort order for dashboard gauge charts.",
             valid_values_text = "desc, asc, or alphabetic",
             dropdown = c("desc", "asc", "alphabetic"))
      )
    ),

    # ---- DASHBOARD THRESHOLDS ----
    list(
      section_name = "DASHBOARD COLOUR THRESHOLDS (RAG)",
      fields = list(
        list(name = "dashboard_scale_mean", default = 10, required = TRUE,
             description = "Scale maximum for mean values in dashboard (e.g., 10 for a 1-10 scale).",
             valid_values_text = "Positive integer",
             integer_range = c(1, 100)),
        list(name = "dashboard_scale_index", default = 10, required = TRUE,
             description = "Scale maximum for index values in dashboard.",
             valid_values_text = "Positive integer",
             integer_range = c(1, 100)),
        list(name = "dashboard_green_net", default = 30, required = TRUE,
             description = "NET POSITIVE >= this value shows GREEN (good performance).",
             valid_values_text = "0 to 100 (%)",
             integer_range = c(0, 100)),
        list(name = "dashboard_amber_net", default = 0, required = TRUE,
             description = "NET POSITIVE >= this value (but < green) shows AMBER. Below = RED.",
             valid_values_text = "0 to 100 (%)",
             integer_range = c(0, 100)),
        list(name = "dashboard_green_mean", default = 7, required = TRUE,
             description = "Mean score >= this value shows GREEN.",
             valid_values_text = "Positive number",
             numeric_range = c(0, 100)),
        list(name = "dashboard_amber_mean", default = 5, required = TRUE,
             description = "Mean score >= this value (but < green) shows AMBER. Below = RED.",
             valid_values_text = "Positive number",
             numeric_range = c(0, 100)),
        list(name = "dashboard_green_index", default = 7, required = TRUE,
             description = "Index score >= this value shows GREEN.",
             valid_values_text = "Positive number",
             numeric_range = c(0, 100)),
        list(name = "dashboard_amber_index", default = 5, required = TRUE,
             description = "Index score >= this value (but < green) shows AMBER. Below = RED.",
             valid_values_text = "Positive number",
             numeric_range = c(0, 100)),
        list(name = "dashboard_green_custom", default = 60, required = TRUE,
             description = "Custom metric >= this value shows GREEN.",
             valid_values_text = "0 to 100 (%)",
             integer_range = c(0, 100)),
        list(name = "dashboard_amber_custom", default = 40, required = TRUE,
             description = "Custom metric >= this value (but < green) shows AMBER. Below = RED.",
             valid_values_text = "0 to 100 (%)",
             integer_range = c(0, 100))
      )
    ),

    # ---- HTML REPORT ----
    list(
      section_name = "HTML REPORT",
      fields = list(
        list(name = "html_report", default = "FALSE", required = TRUE,
             description = "Generate an interactive HTML report in addition to the Excel output.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "brand_colour", default = "#323367", required = TRUE,
             description = "Primary brand colour for HTML report (hex code). Used for headers and charts.",
             valid_values_text = "Hex colour code (e.g. #323367)"),
        list(name = "accent_colour", default = "#CC9900", required = TRUE,
             description = "Accent colour for HTML report highlights and call-outs.",
             valid_values_text = "Hex colour code (e.g. #CC9900)"),
        list(name = "chart_bar_colour", default = "#323367", required = TRUE,
             description = "Colour for bar charts in the HTML report.",
             valid_values_text = "Hex colour code (e.g. #323367)"),
        list(name = "embed_frequencies", default = "TRUE", required = TRUE,
             description = "Include frequency data (counts) in the HTML report tables.",
             valid_values_text = "TRUE or FALSE",
             dropdown = c("TRUE", "FALSE")),
        list(name = "project_title", default = "", required = FALSE,
             description = "Title displayed at the top of the HTML report.",
             valid_values_text = "Any text"),
        list(name = "company_name", default = "The Research Lamppost", required = TRUE,
             description = "Research company name displayed in report footer.",
             valid_values_text = "Any text"),
        list(name = "client_name", default = "", required = FALSE,
             description = "Client organisation name displayed in the report.",
             valid_values_text = "Any text"),
        list(name = "researcher_logo_path", default = "", required = FALSE,
             description = "Path to researcher/company logo file (PNG, SVG, or JPG).",
             valid_values_text = "File path (relative to config)"),
        list(name = "client_logo_path", default = "", required = FALSE,
             description = "Path to client logo file (PNG, SVG, or JPG).",
             valid_values_text = "File path (relative to config)"),
        list(name = "logo_path", default = "", required = FALSE,
             description = "Legacy: single logo path. Use researcher_logo_path instead.",
             valid_values_text = "File path (deprecated)")
      )
    ),

    # ---- ROW DESCRIPTORS ----
    list(
      section_name = "ROW DESCRIPTORS (HTML Report)",
      fields = list(
        list(name = "index_descriptor", default = "", required = FALSE,
             description = "Explanatory label shown below Index score rows in HTML crosstabs.",
             valid_values_text = "e.g. Weighted mean on 0-10 scale"),
        list(name = "mean_descriptor", default = "", required = FALSE,
             description = "Explanatory label shown below Mean score rows in HTML crosstabs.",
             valid_values_text = "e.g. Average rating (1-5 scale)"),
        list(name = "nps_descriptor", default = "", required = FALSE,
             description = "Explanatory label shown below NPS score rows in HTML crosstabs.",
             valid_values_text = "e.g. Promoters minus Detractors"),
        list(name = "priority_metric", default = "", required = FALSE,
             description = "Metric to highlight in the report (used for visual emphasis).",
             valid_values_text = "Any text")
      )
    ),

    # ---- ANALYST / CLOSING ----
    list(
      section_name = "ANALYST & CLOSING SECTION",
      fields = list(
        list(name = "analyst_name", default = "", required = FALSE,
             description = "Analyst name shown in the closing section of HTML report.",
             valid_values_text = "Any text"),
        list(name = "analyst_email", default = "", required = FALSE,
             description = "Analyst email shown in the closing section.",
             valid_values_text = "Email address"),
        list(name = "analyst_phone", default = "", required = FALSE,
             description = "Analyst phone number shown in the closing section.",
             valid_values_text = "Phone number"),
        list(name = "verbatim_filename", default = "", required = FALSE,
             description = "Path to verbatim comments file for inclusion in report.",
             valid_values_text = "File path (relative to config)"),
        list(name = "closing_notes", default = "", required = FALSE,
             description = "Custom text for the closing section of the HTML report.",
             valid_values_text = "Any text (supports markdown)")
      )
    )
  )

  write_settings_sheet(wb, "Settings", settings_def,
                       title = "TURAS Crosstab Configuration",
                       subtitle = "Configure all analysis settings below. Yellow cells are editable. Use dropdowns where available.")

  # --- SHEET 2: Selection ---
  selection_cols <- list(
    list(name = "QuestionCode", width = 20, required = TRUE,
         description = "Question code from Survey_Structure. Must match exactly (case-sensitive). For Multi_Mention, use root code (e.g. Q01 not Q01_1)."),
    list(name = "Include", width = 10, required = TRUE,
         description = "Include this question as a stub (row) in crosstab output.",
         dropdown = c("Y", "N")),
    list(name = "UseBanner", width = 12, required = TRUE,
         description = "Use this question's response options as banner (column) breakout groups.",
         dropdown = c("Y", "N")),
    list(name = "BannerBoxCategory", width = 18, required = FALSE,
         description = "Use BoxCategory groupings instead of individual options for banner columns.",
         dropdown = c("Y", "N")),
    list(name = "BannerLabel", width = 20, required = FALSE,
         description = "Header label for this banner group (e.g. 'Gender', 'Age Group'). Required if UseBanner = Y."),
    list(name = "DisplayOrder", width = 14, required = FALSE,
         description = "Order of banner columns left to right (1 = leftmost, typically Total).",
         integer_range = c(1, 100)),
    list(name = "CreateIndex", width = 13, required = FALSE,
         description = "Calculate mean/index score for this question (Rating, Likert, NPS only).",
         dropdown = c("Y", "N")),
    list(name = "BaseFilter", width = 35, required = FALSE,
         description = "R expression to filter respondents (e.g. Q1 == \"Male\" or !is.na(Q20)). Leave blank for no filter."),
    list(name = "QuestionText", width = 40, required = FALSE,
         description = "Reference only - question wording for your convenience. Not used in processing.")
  )

  # Example selection rows
  selection_examples <- list(
    list(QuestionCode = "Total", Include = "N", UseBanner = "Y",
         BannerBoxCategory = "N", BannerLabel = "Total",
         DisplayOrder = 1, CreateIndex = "N", BaseFilter = "",
         QuestionText = "Total sample (always include as first banner)"),
    list(QuestionCode = "Q_Gender", Include = "N", UseBanner = "Y",
         BannerBoxCategory = "N", BannerLabel = "Gender",
         DisplayOrder = 2, CreateIndex = "N", BaseFilter = "",
         QuestionText = "Example: demographic banner question"),
    list(QuestionCode = "Q_Satisfaction", Include = "Y", UseBanner = "N",
         BannerBoxCategory = "", BannerLabel = "",
         DisplayOrder = "", CreateIndex = "Y", BaseFilter = "",
         QuestionText = "Example: stub question with index score")
  )

  write_table_sheet(wb, "Selection", selection_cols,
                    title = "Question Selection",
                    subtitle = "Define which questions appear as stubs (rows) and banners (columns). Blue rows are examples - overwrite with your data.",
                    example_rows = selection_examples)

  # --- SHEET 3: Base Filters (Reference) ---
  addWorksheet(wb, "Base Filters Reference", gridLines = FALSE)
  setColWidths(wb, "Base Filters Reference", cols = 1:3, widths = c(30, 45, 40))

  writeData(wb, "Base Filters Reference", x = "Base Filter Reference Guide",
            startRow = 1, startCol = 1)
  addStyle(wb, "Base Filters Reference", make_title_style(), rows = 1, cols = 1)
  mergeCells(wb, "Base Filters Reference", cols = 1:3, rows = 1)

  writeData(wb, "Base Filters Reference",
            x = "Use these patterns in the BaseFilter column of the Selection sheet. This sheet is for reference only.",
            startRow = 2, startCol = 1)
  addStyle(wb, "Base Filters Reference", make_subtitle_style(), rows = 2, cols = 1)
  mergeCells(wb, "Base Filters Reference", cols = 1:3, rows = 2)

  filter_headers <- c("Pattern", "Example", "Explanation")
  writeData(wb, "Base Filters Reference", x = data.frame(t(filter_headers)),
            startRow = 4, startCol = 1, colNames = FALSE)
  addStyle(wb, "Base Filters Reference", make_header_style(), rows = 4, cols = 1:3, gridExpand = TRUE)

  filters <- data.frame(
    Pattern = c(
      "Equal to a value",
      "Not equal to a value",
      "Not missing (has answer)",
      "Is missing",
      "Multiple conditions (AND)",
      "Either condition (OR)",
      "Value in a list",
      "Numeric comparison",
      "Text contains"
    ),
    Example = c(
      'Q1 == "Male"',
      'Q1 != "Prefer not to say"',
      "!is.na(Q20)",
      "is.na(Q20)",
      'Q1 == "Male" & Q2 == "18-24"',
      'Q1 == "Male" | Q1 == "Female"',
      'Q1 %in% c("18-24", "25-34")',
      "Q_Age >= 18",
      'grepl("satisfied", Q10, ignore.case = TRUE)'
    ),
    Explanation = c(
      "Only include respondents where Q1 equals 'Male'",
      "Exclude respondents who selected 'Prefer not to say'",
      "Only include respondents who answered Q20",
      "Only include respondents who did NOT answer Q20",
      "Both conditions must be true",
      "Either condition can be true",
      "Q1 must be one of the listed values",
      "Q_Age must be 18 or greater",
      "Q10 response contains the word 'satisfied'"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Base Filters Reference", x = filters, startRow = 5, startCol = 1,
            colNames = FALSE)
  for (r in 5:(5 + nrow(filters) - 1)) {
    addStyle(wb, "Base Filters Reference", make_locked_style(), rows = r, cols = 1:3,
             gridExpand = TRUE)
  }

  # --- SHEET 4: Comments ---
  comments_cols <- list(
    list(name = "QuestionCode", width = 20, required = TRUE,
         description = "Question code to attach comment to, or _BACKGROUND / _EXECUTIVE_SUMMARY for report sections."),
    list(name = "Comment", width = 60, required = TRUE,
         description = "Comment text. Supports markdown for HTML reports (bold, bullets, links)."),
    list(name = "Banner", width = 20, required = FALSE,
         description = "Optional: specific banner column this comment applies to. Leave blank for all banners.")
  )

  comments_examples <- list(
    list(QuestionCode = "_BACKGROUND", Comment = "This survey was conducted among 500 adults nationally in Q1 2025.", Banner = ""),
    list(QuestionCode = "_EXECUTIVE_SUMMARY", Comment = "Key finding: Overall satisfaction increased by 5 points year-on-year.", Banner = ""),
    list(QuestionCode = "Q_Satisfaction", Comment = "Note: Question wording changed from previous wave.", Banner = "")
  )

  write_table_sheet(wb, "Comments", comments_cols,
                    title = "Question Comments & Report Text",
                    subtitle = "Add question-specific comments and report narrative sections. Use _BACKGROUND and _EXECUTIVE_SUMMARY for report sections.",
                    example_rows = comments_examples,
                    num_blank_rows = 30)

  # --- SHEET 5: AddedSlides ---
  slides_cols <- list(
    list(name = "slide_title", width = 30, required = TRUE,
         description = "Title for this additional report section/slide."),
    list(name = "content", width = 70, required = TRUE,
         description = "Content for this section. Supports markdown: **bold**, *italic*, - bullets, [links](url)."),
    list(name = "display_order", width = 14, required = FALSE,
         description = "Order in report (1 = first). Auto-numbered if left blank.",
         integer_range = c(1, 100))
  )

  slides_examples <- list(
    list(slide_title = "Methodology", content = "A nationally representative online survey of n=500 adults aged 18+, conducted January-March 2025.", display_order = 1),
    list(slide_title = "Key Recommendations", content = "- Focus on improving customer service touchpoints\n- Invest in digital channel experience\n- Monitor competitor NPS quarterly", display_order = 2)
  )

  write_table_sheet(wb, "AddedSlides", slides_cols,
                    title = "Additional Report Slides",
                    subtitle = "Add custom narrative slides to the HTML report. Supports markdown formatting.",
                    example_rows = slides_examples,
                    num_blank_rows = 20)

  # Save
  saveWorkbook(wb, output_path, overwrite = TRUE)
  cat(sprintf("\n  [SUCCESS] Crosstab Config template created: %s\n", output_path))
  invisible(output_path)
}


# ==============================================================================
# SURVEY STRUCTURE TEMPLATE
# ==============================================================================

#' Generate a Professional Survey Structure Template
#'
#' Creates a hardened, professionally formatted Survey_Structure.xlsx with
#' dropdown validation, help text, and complete field coverage.
#'
#' @param output_path Path for the output Excel file
#' @return Invisible path to created file
#' @export
generate_survey_structure_template <- function(output_path) {

  wb <- createWorkbook()

  # --- SHEET 1: Project ---
  project_def <- list(
    list(
      section_name = "PROJECT INFORMATION",
      fields = list(
        list(name = "project_name", default = "", required = TRUE,
             description = "Display name for the project shown in reports and output files.",
             valid_values_text = "Any descriptive name"),
        list(name = "project_code", default = "", required = TRUE,
             description = "Unique project identifier code (used in filenames and logging).",
             valid_values_text = "e.g. PRJ2025_001"),
        list(name = "client_name", default = "", required = TRUE,
             description = "Client organisation name for reports and documentation.",
             valid_values_text = "Any text"),
        list(name = "study_type", default = "Ad-hoc", required = TRUE,
             description = "Type of research study. Affects how data is processed and tracked.",
             valid_values_text = "Ad-hoc, Tracker, Panel, or Longitudinal",
             dropdown = c("Ad-hoc", "Tracker", "Panel", "Longitudinal")),
        list(name = "study_date", default = "", required = TRUE,
             description = "Study date in YYYYMMDD format. Used for tracking and documentation.",
             valid_values_text = "YYYYMMDD (e.g. 20250315)"),
        list(name = "contact_person", default = "", required = FALSE,
             description = "Project lead or primary contact name.",
             valid_values_text = "Any text"),
        list(name = "notes", default = "", required = FALSE,
             description = "General project notes or description.",
             valid_values_text = "Any text")
      )
    ),
    list(
      section_name = "DATA FILE",
      fields = list(
        list(name = "data_file", default = "", required = TRUE,
             description = "Path to the survey data file, relative to this config file.",
             valid_values_text = "File path (e.g. Survey_Data.xlsx)"),
        list(name = "output_folder", default = "Output", required = TRUE,
             description = "Folder for output files. Created automatically if it doesn't exist.",
             valid_values_text = "Folder name"),
        list(name = "total_sample", default = "", required = TRUE,
             description = "Expected total number of respondents in the data file.",
             valid_values_text = "Positive integer")
      )
    ),
    list(
      section_name = "WEIGHTING (if applicable)",
      fields = list(
        list(name = "weight_column_exists", default = "N", required = FALSE,
             description = "Does the data file contain weight columns?",
             valid_values_text = "Y or N",
             dropdown = c("Y", "N")),
        list(name = "weight_columns", default = "", required = FALSE,
             description = "Comma-separated list of weight column names. Required if weight_column_exists = Y.",
             valid_values_text = "e.g. weight_nat, weight_region"),
        list(name = "default_weight", default = "", required = FALSE,
             description = "Which weight column to use by default when weighting is enabled.",
             valid_values_text = "One of the weight_columns values"),
        list(name = "weight_description", default = "", required = FALSE,
             description = "Documentation of weighting methodology (rim weighting, post-strat, etc.).",
             valid_values_text = "Any descriptive text")
      )
    )
  )

  write_settings_sheet(wb, "Project", project_def,
                       title = "TURAS Survey Structure - Project Setup",
                       subtitle = "Define project details and data file location. Yellow cells are editable.")

  # --- SHEET 2: Questions ---
  questions_cols <- list(
    list(name = "QuestionCode", width = 18, required = TRUE,
         description = "Unique code matching the column name in data file (case-sensitive). For Multi_Mention, use root code (Q01 not Q01_1)."),
    list(name = "QuestionText", width = 45, required = TRUE,
         description = "Full question wording as it should appear in output reports."),
    list(name = "Variable_Type", width = 18, required = TRUE,
         description = "Type of question. Determines how data is processed and displayed.",
         dropdown = c("Single_Mention", "Multi_Mention", "Likert", "Rating", "NPS", "Ranking", "Numeric", "Open_End")),
    list(name = "Columns", width = 10, required = TRUE,
         description = "Number of data columns: 1 for most types, >1 for Multi_Mention (# options) and Ranking (# items).",
         integer_range = c(1, 500)),
    list(name = "Category", width = 20, required = FALSE,
         description = "Question grouping/section label (e.g. 'Demographics', 'Satisfaction'). Used for report organisation."),
    list(name = "Ranking_Format", width = 16, required = FALSE,
         description = "Required for Ranking questions. Position = each item column has rank number. Item = each rank column has item code.",
         dropdown = c("Position", "Item")),
    list(name = "Ranking_Positions", width = 18, required = FALSE,
         description = "Required for Ranking: how many items each respondent ranks (e.g. 3 for 'rank your top 3').",
         integer_range = c(1, 100)),
    list(name = "Ranking_Direction", width = 18, required = FALSE,
         description = "Required for Ranking: does Rank 1 mean best or worst?",
         dropdown = c("BestToWorst", "WorstToBest")),
    list(name = "Min_Value", width = 12, required = FALSE,
         description = "For Numeric questions: minimum expected value. Used for validation and binning."),
    list(name = "Max_Value", width = 12, required = FALSE,
         description = "For Numeric questions: maximum expected value. Used for validation and binning."),
    list(name = "Notes", width = 30, required = FALSE,
         description = "Internal notes about this question (not shown in output).")
  )

  # Example questions
  questions_examples <- list(
    list(QuestionCode = "Q_Gender", QuestionText = "What is your gender?",
         Variable_Type = "Single_Mention", Columns = 1,
         Category = "Demographics", Notes = "Standard demographic question"),
    list(QuestionCode = "Q_Media", QuestionText = "Which media channels do you use? (Select all)",
         Variable_Type = "Multi_Mention", Columns = 5,
         Category = "Media Usage", Notes = "5 response options = 5 columns (Q_Media_1 to Q_Media_5)"),
    list(QuestionCode = "Q_Satisfaction", QuestionText = "How satisfied are you overall? (1-5)",
         Variable_Type = "Rating", Columns = 1,
         Category = "Satisfaction", Notes = "1 = Very Dissatisfied, 5 = Very Satisfied"),
    list(QuestionCode = "Q_Agreement", QuestionText = "I would recommend this brand to others",
         Variable_Type = "Likert", Columns = 1,
         Category = "Brand", Notes = "Strongly Disagree to Strongly Agree (5-point)"),
    list(QuestionCode = "Q_NPS", QuestionText = "How likely are you to recommend us? (0-10)",
         Variable_Type = "NPS", Columns = 1,
         Category = "Loyalty", Notes = "0-6 Detractors, 7-8 Passives, 9-10 Promoters"),
    list(QuestionCode = "Q_Rank", QuestionText = "Rank your top 3 favourite brands",
         Variable_Type = "Ranking", Columns = 3,
         Category = "Preferences",
         Ranking_Format = "Position", Ranking_Positions = 3,
         Ranking_Direction = "BestToWorst",
         Notes = "3 columns: Q_Rank_1, Q_Rank_2, Q_Rank_3"),
    list(QuestionCode = "Q_Age", QuestionText = "What is your age?",
         Variable_Type = "Numeric", Columns = 1,
         Category = "Demographics", Min_Value = 18, Max_Value = 99,
         Notes = "Open numeric - will bin if Options sheet has Min/Max"),
    list(QuestionCode = "Q_Comments", QuestionText = "Any additional comments?",
         Variable_Type = "Open_End", Columns = 1,
         Category = "Verbatim", Notes = "Text responses - not processed in crosstabs")
  )

  write_table_sheet(wb, "Questions", questions_cols,
                    title = "Question Definitions",
                    subtitle = "Define every survey question. Blue rows are examples - overwrite with your actual questions. Variable_Type determines processing logic.",
                    example_rows = questions_examples)

  # --- SHEET 3: Options ---
  options_cols <- list(
    list(name = "QuestionCode", width = 18, required = TRUE,
         description = "Links to Questions sheet. For Multi_Mention: use individual column codes (Q01_1, Q01_2). For others: use the main QuestionCode."),
    list(name = "OptionText", width = 25, required = TRUE,
         description = "EXACT value from data file (case-sensitive). If data has '1', enter '1' not 'Male'. Must match data precisely."),
    list(name = "DisplayText", width = 30, required = TRUE,
         description = "How this option appears in output. OptionText '1' can display as 'Male'. This is what users see."),
    list(name = "DisplayOrder", width = 14, required = FALSE,
         description = "Order in output tables (1 = first). Auto-ordered if left blank.",
         integer_range = c(1, 500)),
    list(name = "ShowInOutput", width = 14, required = TRUE,
         description = "Show this option in output tables. Set to Y. Leave blank to hide (e.g. internal codes).",
         dropdown = c("Y", "")),
    list(name = "ExcludeFromIndex", width = 18, required = FALSE,
         description = "Exclude from mean/index calculations (e.g. 'Don\\'t know', 'N/A'). Y = exclude.",
         dropdown = c("Y", "")),
    list(name = "Index_Weight", width = 14, required = FALSE,
         description = "Numeric weight for index calculation. Rating: scale value (1-5). Likert: custom weight (-100 to 100)."),
    list(name = "OptionValue", width = 14, required = FALSE,
         description = "Alternative numeric value for calculations (used instead of OptionText if present)."),
    list(name = "BoxCategory", width = 20, required = FALSE,
         description = "Group options into summary categories (e.g. 'Top 2 Box', 'Satisfied', 'Promoters')."),
    list(name = "Min", width = 10, required = FALSE,
         description = "For Numeric binning: minimum value of this range (e.g. 18 for '18-24' bin)."),
    list(name = "Max", width = 10, required = FALSE,
         description = "For Numeric binning: maximum value of this range (e.g. 24 for '18-24' bin).")
  )

  # Example options
  options_examples <- list(
    # Gender
    list(QuestionCode = "Q_Gender", OptionText = "1", DisplayText = "Male",
         DisplayOrder = 1, ShowInOutput = "Y"),
    list(QuestionCode = "Q_Gender", OptionText = "2", DisplayText = "Female",
         DisplayOrder = 2, ShowInOutput = "Y"),
    list(QuestionCode = "Q_Gender", OptionText = "3", DisplayText = "Other / Prefer not to say",
         DisplayOrder = 3, ShowInOutput = "Y"),
    # Multi_Mention (individual columns)
    list(QuestionCode = "Q_Media_1", OptionText = "1", DisplayText = "Television",
         DisplayOrder = 1, ShowInOutput = "Y"),
    list(QuestionCode = "Q_Media_2", OptionText = "1", DisplayText = "Radio",
         DisplayOrder = 2, ShowInOutput = "Y"),
    # Rating with Index_Weight
    list(QuestionCode = "Q_Satisfaction", OptionText = "1", DisplayText = "Very Dissatisfied",
         DisplayOrder = 1, ShowInOutput = "Y", Index_Weight = 1, BoxCategory = "Bottom 2 Box"),
    list(QuestionCode = "Q_Satisfaction", OptionText = "2", DisplayText = "Dissatisfied",
         DisplayOrder = 2, ShowInOutput = "Y", Index_Weight = 2, BoxCategory = "Bottom 2 Box"),
    list(QuestionCode = "Q_Satisfaction", OptionText = "3", DisplayText = "Neutral",
         DisplayOrder = 3, ShowInOutput = "Y", Index_Weight = 3),
    list(QuestionCode = "Q_Satisfaction", OptionText = "4", DisplayText = "Satisfied",
         DisplayOrder = 4, ShowInOutput = "Y", Index_Weight = 4, BoxCategory = "Top 2 Box"),
    list(QuestionCode = "Q_Satisfaction", OptionText = "5", DisplayText = "Very Satisfied",
         DisplayOrder = 5, ShowInOutput = "Y", Index_Weight = 5, BoxCategory = "Top 2 Box"),
    # Likert with custom weights
    list(QuestionCode = "Q_Agreement", OptionText = "1", DisplayText = "Strongly Disagree",
         DisplayOrder = 1, ShowInOutput = "Y", Index_Weight = -100, BoxCategory = "Disagree"),
    list(QuestionCode = "Q_Agreement", OptionText = "2", DisplayText = "Disagree",
         DisplayOrder = 2, ShowInOutput = "Y", Index_Weight = -50, BoxCategory = "Disagree"),
    list(QuestionCode = "Q_Agreement", OptionText = "3", DisplayText = "Neutral",
         DisplayOrder = 3, ShowInOutput = "Y", Index_Weight = 0),
    list(QuestionCode = "Q_Agreement", OptionText = "4", DisplayText = "Agree",
         DisplayOrder = 4, ShowInOutput = "Y", Index_Weight = 50, BoxCategory = "Agree"),
    list(QuestionCode = "Q_Agreement", OptionText = "5", DisplayText = "Strongly Agree",
         DisplayOrder = 5, ShowInOutput = "Y", Index_Weight = 100, BoxCategory = "Agree"),
    # Numeric binning
    list(QuestionCode = "Q_Age", OptionText = "18-24", DisplayText = "18-24",
         DisplayOrder = 1, ShowInOutput = "Y", Min = 18, Max = 24),
    list(QuestionCode = "Q_Age", OptionText = "25-34", DisplayText = "25-34",
         DisplayOrder = 2, ShowInOutput = "Y", Min = 25, Max = 34)
  )

  write_table_sheet(wb, "Options", options_cols,
                    title = "Response Options",
                    subtitle = "Define all response options for each question. OptionText MUST exactly match your data values. Blue rows are examples.",
                    example_rows = options_examples,
                    num_blank_rows = 200)

  # --- SHEET 4: Composite_Metrics ---
  composite_cols <- list(
    list(name = "CompositeCode", width = 22, required = TRUE,
         description = "Unique identifier for this composite score (e.g. COMP_SAT_OVERALL). Used as sheet name."),
    list(name = "CompositeLabel", width = 35, required = TRUE,
         description = "Display name shown in output (e.g. 'Overall Satisfaction Index')."),
    list(name = "CalculationType", width = 18, required = TRUE,
         description = "How to combine source questions: Mean (average), Sum (total), or WeightedMean (weighted average).",
         dropdown = c("Mean", "Sum", "WeightedMean")),
    list(name = "SourceQuestions", width = 35, required = TRUE,
         description = "Comma-separated list of QuestionCodes to include (e.g. Q01,Q02,Q03). Must exist in Questions sheet."),
    list(name = "Weights", width = 25, required = FALSE,
         description = "Required if CalculationType = WeightedMean. Comma-separated weights, one per source question (e.g. 1,2,1)."),
    list(name = "SectionLabel", width = 25, required = FALSE,
         description = "Groups related composites in the Index Summary (e.g. 'Satisfaction Metrics', 'Brand Health')."),
    list(name = "ExcludeFromSummary", width = 20, required = FALSE,
         description = "Y = hide this composite from the Index_Summary sheet.",
         dropdown = c("Y", "")),
    list(name = "Notes", width = 30, required = FALSE,
         description = "Internal documentation notes (not shown in output).")
  )

  composite_examples <- list(
    list(CompositeCode = "COMP_SAT_OVERALL", CompositeLabel = "Overall Satisfaction Index",
         CalculationType = "Mean", SourceQuestions = "Q_Sat1,Q_Sat2,Q_Sat3",
         SectionLabel = "Satisfaction Metrics",
         Notes = "Simple mean of 3 satisfaction questions"),
    list(CompositeCode = "COMP_BRAND_HEALTH", CompositeLabel = "Brand Health Score",
         CalculationType = "WeightedMean", SourceQuestions = "Q_Aware,Q_Consider,Q_Prefer",
         Weights = "1,2,3", SectionLabel = "Brand Metrics",
         Notes = "Preference weighted 3x, consideration 2x")
  )

  write_table_sheet(wb, "Composite_Metrics", composite_cols,
                    title = "Composite Metrics",
                    subtitle = "Define calculated composite scores that combine multiple questions. Blue rows are examples.",
                    example_rows = composite_examples,
                    num_blank_rows = 20)

  # --- SHEET 5: Variable Type Reference ---
  addWorksheet(wb, "Variable Type Reference", gridLines = FALSE)
  setColWidths(wb, "Variable Type Reference", cols = 1:5, widths = c(18, 35, 10, 20, 35))

  writeData(wb, "Variable Type Reference", x = "Variable Type Reference Guide",
            startRow = 1, startCol = 1)
  addStyle(wb, "Variable Type Reference", make_title_style(), rows = 1, cols = 1)
  mergeCells(wb, "Variable Type Reference", cols = 1:5, rows = 1)

  writeData(wb, "Variable Type Reference",
            x = "Use this sheet as a reference for choosing the correct Variable_Type. This sheet is not processed.",
            startRow = 2, startCol = 1)
  addStyle(wb, "Variable Type Reference", make_subtitle_style(), rows = 2, cols = 1)
  mergeCells(wb, "Variable Type Reference", cols = 1:5, rows = 2)

  ref_headers <- c("Variable_Type", "Description", "Columns", "Key Features", "Example")
  writeData(wb, "Variable Type Reference", x = data.frame(t(ref_headers)),
            startRow = 4, startCol = 1, colNames = FALSE)
  addStyle(wb, "Variable Type Reference", make_header_style(), rows = 4, cols = 1:5, gridExpand = TRUE)

  ref_data <- data.frame(
    Variable_Type = c("Single_Mention", "Multi_Mention", "Likert", "Rating", "NPS", "Ranking", "Numeric", "Open_End"),
    Description = c(
      "Pick-one question: respondent selects exactly one option",
      "Check-all-that-apply: respondent can select multiple options",
      "Agreement scale with custom index weights",
      "Numeric scale where the mean is meaningful",
      "Net Promoter Score (0-10 scale)",
      "Ordered preference ranking of items",
      "Open-ended numeric response (age, income, quantity)",
      "Free text response (not processed in crosstabs)"
    ),
    Columns = c("1", ">1 (# options)", "1", "1", "1", ">1 (# items)", "1", "1"),
    Key_Features = c(
      "Frequencies, column %, significance tests",
      "Each option = own column. Use root code in Questions, column codes in Options",
      "Frequencies + custom-weighted Index score + NET POSITIVE",
      "Frequencies + Mean score + optional SD",
      "Auto-calculates Promoters/Passives/Detractors + NPS score",
      "Rank analysis with average rank, first-choice share",
      "Mean, median, mode, outlier detection, binning via Options",
      "Displayed as text, no statistical analysis"
    ),
    Example = c(
      "Gender, Yes/No, Preferred brand",
      "Media channels used, Features desired",
      "Agree/Disagree scales, Brand attribute ratings",
      "Satisfaction 1-5, Likelihood 1-10",
      "Recommendation likelihood 0-10",
      "Rank top 3 brands, Rank features by importance",
      "Age, Household size, Monthly spend",
      "Comments, Suggestions, Feedback"
    ),
    stringsAsFactors = FALSE
  )

  writeData(wb, "Variable Type Reference", x = ref_data, startRow = 5, startCol = 1,
            colNames = FALSE)
  for (r in 5:(5 + nrow(ref_data) - 1)) {
    addStyle(wb, "Variable Type Reference", make_locked_style(), rows = r, cols = 1:5,
             gridExpand = TRUE)
  }
  setRowHeights(wb, "Variable Type Reference", rows = 5:(5 + nrow(ref_data) - 1), heights = 50)

  # Save
  saveWorkbook(wb, output_path, overwrite = TRUE)
  cat(sprintf("\n  [SUCCESS] Survey Structure template created: %s\n", output_path))
  invisible(output_path)
}


# ==============================================================================
# CONVENIENCE: Generate All Templates
# ==============================================================================

#' Generate All Config Templates
#'
#' Creates both Crosstab_Config and Survey_Structure templates in a directory.
#'
#' @param output_dir Directory to create templates in
#' @param config_filename Filename for config template (default: "Crosstab_Config.xlsx")
#' @param structure_filename Filename for structure template (default: "Survey_Structure.xlsx")
#' @return Invisible list of created file paths
#' @export
generate_all_templates <- function(output_dir,
                                    config_filename = "Crosstab_Config.xlsx",
                                    structure_filename = "Survey_Structure.xlsx") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    cat(sprintf("  Created directory: %s\n", output_dir))
  }

  config_path <- file.path(output_dir, config_filename)
  structure_path <- file.path(output_dir, structure_filename)

  generate_survey_structure_template(structure_path)
  generate_crosstab_config_template(config_path, structure_file = structure_filename)

  cat("\n  ========================================\n")
  cat("  All templates generated successfully!\n")
  cat("  ========================================\n")
  cat(sprintf("  Config:    %s\n", config_path))
  cat(sprintf("  Structure: %s\n", structure_path))
  cat("\n  Next steps:\n")
  cat("  1. Open Survey_Structure.xlsx and fill in your project details & questions\n")
  cat("  2. Open Crosstab_Config.xlsx and adjust analysis settings\n")
  cat("  3. Run your analysis!\n\n")

  invisible(list(config = config_path, structure = structure_path))
}
