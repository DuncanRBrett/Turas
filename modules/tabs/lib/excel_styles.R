# ==============================================================================
# MODULE: EXCEL_STYLES.R
# ==============================================================================
#
# PURPOSE:
#   Define Excel formatting styles for crosstab output
#
# FUNCTIONS:
#   - create_excel_styles() - Create all formatting styles
#   - get_row_style() - Get appropriate style for a row type
#
# DEPENDENCIES:
#   - openxlsx (Excel styling)
#   - /modules/shared/lib/formatting_utils.R (number format generation)
#
# VERSION: 1.3.0 - Extracted from excel_writer.R for maintainability
# DATE: 2025-12-27
# CHANGES: Refactored into focused module for better organization
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
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs excel_styles module loaded")

# ==============================================================================
# END OF MODULE: EXCEL_STYLES.R
# ==============================================================================
