# ==============================================================================
# TURAS KEY DRIVER - QUADRANT EXPORT FUNCTIONS
# ==============================================================================
#
# Purpose: Export quadrant analysis results to Excel and image files
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Export Quadrant Results to Excel
#'
#' Writes quadrant analysis results to Excel workbook.
#'
#' @param quadrant_results Results from create_quadrant_analysis()
#' @param wb openxlsx workbook object (optional - creates new if NULL)
#' @param output_file Path to output Excel file (used if wb is NULL)
#' @return Updated workbook object
#' @keywords internal
export_quadrant_to_excel <- function(quadrant_results, wb = NULL, output_file = NULL) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    keydriver_refuse(
      code = "FEATURE_QUADRANT_OPENXLSX_MISSING",
      title = "openxlsx Package Required",
      problem = "Package 'openxlsx' is required for Excel export but not installed.",
      why_it_matters = "Quadrant results cannot be exported to Excel without openxlsx.",
      how_to_fix = "Install openxlsx: install.packages('openxlsx')"
    )
  }

  # Create workbook if not provided
  create_new <- is.null(wb)
  if (create_new) {
    wb <- openxlsx::createWorkbook()
  }

  # Header style
  header_style <- openxlsx::createStyle(
    fontSize = 11,
    fontColour = "#FFFFFF",
    fgFill = "#27AE60",  # Green for quadrant sheets
    halign = "left",
    valign = "center",
    textDecoration = "bold",
    border = "TopBottomLeftRight"
  )

  # Quadrant color styles
  q1_style <- openxlsx::createStyle(fgFill = "#FADBD8")  # Light red
  q2_style <- openxlsx::createStyle(fgFill = "#D5F5E3")  # Light green
  q3_style <- openxlsx::createStyle(fgFill = "#E5E8E8")  # Light gray
  q4_style <- openxlsx::createStyle(fgFill = "#FCF3CF")  # Light yellow

  # ----------------------------------------------------------------------
  # Sheet: Quadrant_Summary
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Quadrant_Summary")

  quad_data <- quadrant_results$data
  if (!is.null(quad_data)) {
    summary_df <- data.frame(
      Driver = quad_data$driver,
      Importance = round(quad_data$y, 1),
      Performance = round(quad_data$x, 1),
      Gap = round(quad_data$gap, 1),
      Quadrant = quad_data$quadrant,
      Zone = as.character(quad_data$quadrant_label),
      Priority_Score = round(quad_data$priority_score, 1),
      stringsAsFactors = FALSE
    )

    # Sort by priority
    summary_df <- summary_df[order(-summary_df$Priority_Score), ]
    rownames(summary_df) <- NULL

    openxlsx::writeData(wb, "Quadrant_Summary", summary_df, startRow = 1)
    openxlsx::addStyle(wb, "Quadrant_Summary", header_style, rows = 1,
                       cols = 1:ncol(summary_df), gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Quadrant_Summary",
                           cols = 1:ncol(summary_df), widths = "auto")

    # Color rows by quadrant
    for (i in seq_len(nrow(summary_df))) {
      q <- summary_df$Quadrant[i]
      style <- switch(as.character(q),
                      "1" = q1_style, "2" = q2_style,
                      "3" = q3_style, "4" = q4_style, NULL)
      if (!is.null(style)) {
        openxlsx::addStyle(wb, "Quadrant_Summary", style, rows = i + 1,
                           cols = 1:ncol(summary_df), gridExpand = TRUE)
      }
    }
  }

  # ----------------------------------------------------------------------
  # Sheet: Action_Table
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Action_Table")

  action_table <- quadrant_results$action_table
  if (!is.null(action_table)) {
    openxlsx::writeData(wb, "Action_Table", action_table, startRow = 1)
    openxlsx::addStyle(wb, "Action_Table", header_style, rows = 1,
                       cols = 1:ncol(action_table), gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Action_Table",
                           cols = 1:ncol(action_table), widths = "auto")
    # Make action column wider
    openxlsx::setColWidths(wb, "Action_Table", cols = ncol(action_table), widths = 60)
  }

  # ----------------------------------------------------------------------
  # Sheet: Gap_Analysis
  # ----------------------------------------------------------------------
  openxlsx::addWorksheet(wb, "Gap_Analysis")

  gap_data <- quadrant_results$gap_analysis
  if (!is.null(gap_data)) {
    gap_export <- data.frame(
      Rank = gap_data$gap_rank,
      Driver = gap_data$driver,
      Importance = round(gap_data$importance, 1),
      Performance = round(gap_data$performance, 1),
      Gap = round(gap_data$gap, 1),
      Weighted_Gap = round(gap_data$weighted_gap, 2),
      Direction = gap_data$gap_direction,
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, "Gap_Analysis", gap_export, startRow = 1)
    openxlsx::addStyle(wb, "Gap_Analysis", header_style, rows = 1,
                       cols = 1:ncol(gap_export), gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Gap_Analysis",
                           cols = 1:ncol(gap_export), widths = "auto")
  }

  # ----------------------------------------------------------------------
  # Sheet: Segment_Comparison (if available)
  # ----------------------------------------------------------------------
  if (!is.null(quadrant_results$segments) &&
      !is.null(quadrant_results$segments$rank_table)) {

    openxlsx::addWorksheet(wb, "Segment_Comparison")

    rank_table <- quadrant_results$segments$rank_table
    openxlsx::writeData(wb, "Segment_Comparison", rank_table, startRow = 1)
    openxlsx::addStyle(wb, "Segment_Comparison", header_style, rows = 1,
                       cols = 1:ncol(rank_table), gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Segment_Comparison",
                           cols = 1:ncol(rank_table), widths = "auto")
  }

  # Save if new workbook
  if (create_new && !is.null(output_file)) {
    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  }

  invisible(wb)
}


#' Export Quadrant Plots to Files
#'
#' Saves all quadrant plots as PNG and optionally PDF files.
#'
#' @param plots List of ggplot objects
#' @param output_dir Directory to save plots
#' @param prefix Filename prefix
#' @param formats Character vector of formats ("png", "pdf")
#' @param width Plot width in inches
#' @param height Plot height in inches
#' @param dpi Resolution for PNG files
#' @return Vector of saved file paths
#' @keywords internal
export_quadrant_plots <- function(plots, output_dir, prefix = "quadrant",
                                  formats = c("png"), width = 10, height = 10,
                                  dpi = 300) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    warning("Package 'ggplot2' required for plot export.")
    return(invisible(NULL))
  }

  # Create output directory if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  saved_files <- character()

  for (name in names(plots)) {
    p <- plots[[name]]

    if (is.null(p)) next
    if (!inherits(p, "ggplot") && !inherits(p, "patchwork")) next

    # Adjust dimensions for specific plots
    plot_width <- width
    plot_height <- height

    if (name == "gap_chart") {
      plot_width <- 10
      plot_height <- 8
    }

    for (fmt in formats) {
      filepath <- file.path(output_dir, paste0(prefix, "_", name, ".", fmt))

      tryCatch({
        ggplot2::ggsave(
          filepath,
          plot = p,
          width = plot_width,
          height = plot_height,
          dpi = if (fmt == "png") dpi else NA
        )
        saved_files <- c(saved_files, filepath)
      }, error = function(e) {
        warning(sprintf("Could not save %s: %s", filepath, e$message))
      })
    }
  }

  invisible(saved_files)
}


#' Insert Quadrant Charts into Excel Workbook
#'
#' Adds quadrant visualizations to an Excel worksheet.
#'
#' @param wb openxlsx workbook object
#' @param plots List of ggplot objects
#' @param sheet_name Name for the charts sheet
#' @return Updated workbook object
#' @keywords internal
insert_quadrant_charts_to_excel <- function(wb, plots, sheet_name = "Quadrant_Charts") {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    warning("ggplot2 required for chart insertion.")
    return(wb)
  }

  # Add worksheet if it doesn't exist
  sheet_names <- openxlsx::sheets(wb)
  if (!sheet_name %in% sheet_names) {
    openxlsx::addWorksheet(wb, sheet_name)
  }

  row_pos <- 1

  # Priority order for plots
  priority_plots <- c("standard_ipa", "gap_chart", "dual_importance", "segment_comparison")

  for (plot_name in priority_plots) {
    if (!plot_name %in% names(plots)) next

    p <- plots[[plot_name]]
    if (is.null(p)) next
    if (!inherits(p, "ggplot") && !inherits(p, "patchwork")) next

    # Save to temp file
    temp_file <- tempfile(fileext = ".png")

    tryCatch({
      ggplot2::ggsave(temp_file, plot = p, width = 10, height = 8, dpi = 150)

      # Add label
      openxlsx::writeData(wb, sheet_name,
                          data.frame(Chart = gsub("_", " ", toupper(plot_name))),
                          startRow = row_pos, startCol = 1)

      # Insert image
      openxlsx::insertImage(
        wb,
        sheet = sheet_name,
        file = temp_file,
        startRow = row_pos + 1,
        startCol = 1,
        width = 8,
        height = 6.5,
        units = "in"
      )

      row_pos <- row_pos + 28  # Space for next chart

    }, error = function(e) {
      warning(sprintf("Could not insert chart %s: %s", plot_name, e$message))
    })
  }

  invisible(wb)
}
