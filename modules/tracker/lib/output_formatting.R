# ==============================================================================
# OUTPUT FORMATTING MODULE
# ==============================================================================
# Purpose: Excel style definitions and formatting utilities for tracker output
#
# This module extracts Excel style creation from tracker_output.R to improve
# code organization and reusability.
#
# Author: Claude (Refactoring)
# Date: 2025-12-28
# Extracted from: tracker_output.R
# ==============================================================================

#' Create Tracker Excel Styles
#'
#' Creates a list of openxlsx style objects used for formatting tracker output.
#'
#' @return List of openxlsx style objects
#' @export
create_tracker_styles <- function() {

  list(
    title = openxlsx::createStyle(
      fontSize = 14,
      textDecoration = "bold",
      halign = "left"
    ),
    header = openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      halign = "center",
      valign = "center",
      fgFill = "#4472C4",
      fontColour = "#FFFFFF",
      border = "TopBottomLeftRight",
      borderColour = "#FFFFFF",
      wrapText = TRUE
    ),
    wave_header = openxlsx::createStyle(
      fontSize = 11,
      textDecoration = "bold",
      halign = "center",
      fgFill = "#B4C7E7",
      border = "TopBottomLeftRight"
    ),
    metric_label = openxlsx::createStyle(
      fontSize = 10,
      halign = "left",
      valign = "center",
      indent = 1
    ),
    data_number = openxlsx::createStyle(
      fontSize = 10,
      halign = "center",
      valign = "center",
      numFmt = "0.0"
    ),
    data_percent = openxlsx::createStyle(
      fontSize = 10,
      halign = "center",
      valign = "center",
      numFmt = "0"
    ),
    data_integer = openxlsx::createStyle(
      fontSize = 10,
      halign = "center",
      valign = "center",
      numFmt = "0"
    ),
    change_positive = openxlsx::createStyle(
      fontSize = 10,
      halign = "center",
      fontColour = "#008000"
    ),
    change_negative = openxlsx::createStyle(
      fontSize = 10,
      halign = "center",
      fontColour = "#C00000"
    ),
    significant = openxlsx::createStyle(
      fontSize = 10,
      halign = "center",
      textDecoration = "bold",
      fontColour = "#0000FF"
    )
  )
}


# ==============================================================================
# END OF OUTPUT FORMATTING MODULE
# ==============================================================================
