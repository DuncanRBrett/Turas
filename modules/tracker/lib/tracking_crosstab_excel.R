# ==============================================================================
# TurasTracker - Tracking Crosstab Excel Output
# ==============================================================================
#
# Writes the tracking crosstab data structure to a formatted Excel workbook.
# Layout: Rows = tracked metrics with change sub-rows,
#         Columns = waves nested within banner segments.
#
# VERSION: 1.0.0
# ==============================================================================


#' Write Tracking Crosstab Output
#'
#' Creates a formatted Excel workbook containing the tracking crosstab report.
#'
#' @param crosstab_data List. Output from build_tracking_crosstab()
#' @param config List. Configuration object
#' @param output_path Character. Path for output Excel file
#' @param run_result List. Optional TRS run status
#' @return Character. Path to the generated Excel file
#'
#' @export
write_tracking_crosstab_output <- function(crosstab_data, config, output_path,
                                            run_result = NULL) {

  cat("\n  Generating Tracking Crosstab Excel report...\n")

  wb <- openxlsx::createWorkbook()
  styles <- create_crosstab_styles()

  # Sheet 1: Summary
  write_crosstab_summary_sheet(wb, crosstab_data, config, styles)

  # Sheet 2: Tracking Crosstab
  write_crosstab_data_sheet(wb, crosstab_data, config, styles)

  # Save workbook
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  cat(paste0("  Tracking Crosstab saved to: ", output_path, "\n"))

  return(output_path)
}


#' Create Crosstab Excel Styles
#'
#' Extends tracker styles with crosstab-specific formatting.
#'
#' @keywords internal
create_crosstab_styles <- function() {
  list(
    title = openxlsx::createStyle(
      fontSize = 14, textDecoration = "bold", halign = "left"
    ),
    segment_header = openxlsx::createStyle(
      fontSize = 11, textDecoration = "bold", halign = "center", valign = "center",
      fgFill = "#4472C4", fontColour = "#FFFFFF",
      border = "TopBottomLeftRight", borderColour = "#D9E2F3"
    ),
    wave_header = openxlsx::createStyle(
      fontSize = 10, textDecoration = "bold", halign = "center",
      fgFill = "#D9E2F3", border = "TopBottomLeftRight"
    ),
    section_header = openxlsx::createStyle(
      fontSize = 11, textDecoration = "bold", halign = "left",
      fgFill = "#E2EFDA", border = "Bottom"
    ),
    metric_label = openxlsx::createStyle(
      fontSize = 10, halign = "left", valign = "center",
      textDecoration = "bold"
    ),
    sub_metric_label = openxlsx::createStyle(
      fontSize = 9, halign = "left", valign = "center",
      indent = 1
    ),
    change_label = openxlsx::createStyle(
      fontSize = 9, halign = "left", valign = "center",
      indent = 2, fontColour = "#666666"
    ),
    value_number = openxlsx::createStyle(
      fontSize = 10, halign = "center", numFmt = "0.0"
    ),
    value_percent = openxlsx::createStyle(
      fontSize = 10, halign = "center", numFmt = "0%"
    ),
    value_nps = openxlsx::createStyle(
      fontSize = 10, halign = "center", numFmt = "+0;-0;0"
    ),
    change_positive = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#008000"
    ),
    change_negative = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#C00000"
    ),
    change_neutral = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#666666"
    ),
    change_row_bg = openxlsx::createStyle(
      fgFill = "#F5F5F5"
    ),
    sig_positive = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#008000", textDecoration = "bold"
    ),
    sig_negative = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#C00000", textDecoration = "bold"
    ),
    base_row = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#999999", numFmt = "0"
    ),
    info_text = openxlsx::createStyle(
      fontSize = 10, halign = "left", valign = "top", wrapText = TRUE
    )
  )
}


#' Write Summary Sheet
#'
#' @keywords internal
write_crosstab_summary_sheet <- function(wb, crosstab_data, config, styles) {
  sheet_name <- "Summary"
  openxlsx::addWorksheet(wb, sheet_name)

  row <- 1

  # Title
  project_name <- get_setting(config, "project_name", default = "Tracking Report")
  openxlsx::writeData(wb, sheet_name, paste0(project_name, " - Tracking Crosstab"), startRow = row, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$title, rows = row, cols = 1)
  row <- row + 2

  # Metadata
  meta_items <- list(
    c("Generated", format(crosstab_data$metadata$generated_at, "%Y-%m-%d %H:%M")),
    c("Waves", paste(crosstab_data$wave_labels, collapse = ", ")),
    c("Baseline Wave", paste0(crosstab_data$baseline_wave, " (",
      crosstab_data$wave_labels[which(crosstab_data$waves == crosstab_data$baseline_wave)], ")")),
    c("Banner Segments", paste(crosstab_data$banner_segments, collapse = ", ")),
    c("Metrics Tracked", as.character(crosstab_data$metadata$n_metrics)),
    c("Confidence Level", paste0(crosstab_data$metadata$confidence_level * 100, "%"))
  )

  for (item in meta_items) {
    openxlsx::writeData(wb, sheet_name, item[1], startRow = row, startCol = 1)
    openxlsx::writeData(wb, sheet_name, item[2], startRow = row, startCol = 2)
    openxlsx::addStyle(wb, sheet_name, styles$info_text, rows = row, cols = 1:2, gridExpand = TRUE)
    row <- row + 1
  }

  row <- row + 1

  # Sections summary
  if (length(crosstab_data$sections) > 0) {
    openxlsx::writeData(wb, sheet_name, "Report Sections:", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet_name, openxlsx::createStyle(textDecoration = "bold"), rows = row, cols = 1)
    row <- row + 1
    for (sec in crosstab_data$sections) {
      n_in_sec <- sum(vapply(crosstab_data$metrics, function(m) {
        s <- m$section
        if (is.na(s) || s == "") s <- "(Ungrouped)"
        s == sec
      }, logical(1)))
      openxlsx::writeData(wb, sheet_name, paste0("  ", sec, " (", n_in_sec, " metrics)"),
                          startRow = row, startCol = 1)
      row <- row + 1
    }
  }

  # Legend
  row <- row + 2
  openxlsx::writeData(wb, sheet_name, "Legend:", startRow = row, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, openxlsx::createStyle(textDecoration = "bold"), rows = row, cols = 1)
  row <- row + 1
  legend_items <- list(
    c("vs Prev", "Change compared to previous wave"),
    c("vs Base", paste0("Change compared to baseline (", crosstab_data$baseline_wave, ")")),
    c(paste0("\u2191"), "Significant increase"),
    c(paste0("\u2193"), "Significant decrease"),
    c(paste0("\u2192"), "No significant change")
  )
  for (item in legend_items) {
    openxlsx::writeData(wb, sheet_name, item[1], startRow = row, startCol = 1)
    openxlsx::writeData(wb, sheet_name, item[2], startRow = row, startCol = 2)
    row <- row + 1
  }

  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 20)
  openxlsx::setColWidths(wb, sheet_name, cols = 2, widths = 60)
}


#' Write Tracking Crosstab Data Sheet
#'
#' Writes the main tracking crosstab data to an Excel sheet.
#'
#' @keywords internal
write_crosstab_data_sheet <- function(wb, crosstab_data, config, styles) {
  sheet_name <- "Tracking Crosstab"
  openxlsx::addWorksheet(wb, sheet_name)

  waves <- crosstab_data$waves
  wave_labels <- crosstab_data$wave_labels
  segments <- crosstab_data$banner_segments
  n_waves <- length(waves)
  n_segments <- length(segments)

  # Column layout:
  # Col 1: Metric label
  # Then for each segment: n_waves columns (one per wave)
  # Total data columns: n_segments * n_waves
  total_data_cols <- n_segments * n_waves

  row <- 1

  # ---- Row 1: Segment headers (merged across wave columns) ----
  openxlsx::writeData(wb, sheet_name, "Metric", startRow = row, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$segment_header, rows = row, cols = 1)

  col <- 2
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    start_col <- col
    end_col <- col + n_waves - 1

    openxlsx::writeData(wb, sheet_name, seg_name, startRow = row, startCol = start_col)
    if (n_waves > 1) {
      openxlsx::mergeCells(wb, sheet_name, cols = start_col:end_col, rows = row)
    }
    openxlsx::addStyle(wb, sheet_name, styles$segment_header,
                       rows = row, cols = start_col:end_col, gridExpand = TRUE)
    col <- end_col + 1
  }

  row <- row + 1

  # ---- Row 2: Wave headers (repeated per segment) ----
  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 1)
  openxlsx::addStyle(wb, sheet_name, styles$wave_header, rows = row, cols = 1)

  col <- 2
  for (seg_idx in seq_along(segments)) {
    for (w_idx in seq_along(waves)) {
      openxlsx::writeData(wb, sheet_name, wave_labels[w_idx], startRow = row, startCol = col)
      openxlsx::addStyle(wb, sheet_name, styles$wave_header, rows = row, cols = col)
      col <- col + 1
    }
  }

  row <- row + 1

  # ---- Data rows: metrics with change sub-rows ----
  current_section <- ""

  for (metric_row in crosstab_data$metrics) {
    metric_section <- metric_row$section
    if (is.na(metric_section) || metric_section == "") metric_section <- "(Ungrouped)"

    # Section divider
    if (metric_section != current_section) {
      current_section <- metric_section
      openxlsx::writeData(wb, sheet_name, current_section, startRow = row, startCol = 1)
      openxlsx::mergeCells(wb, sheet_name, cols = 1:(1 + total_data_cols), rows = row)
      openxlsx::addStyle(wb, sheet_name, styles$section_header,
                         rows = row, cols = 1:(1 + total_data_cols), gridExpand = TRUE)
      row <- row + 1
    }

    # ---- Value row ----
    openxlsx::writeData(wb, sheet_name, metric_row$metric_label, startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = row, cols = 1)

    col <- 2
    for (seg_name in segments) {
      seg_data <- metric_row$segments[[seg_name]]
      for (wave_id in waves) {
        val <- seg_data$values[[wave_id]]
        if (!is.na(val)) {
          openxlsx::writeData(wb, sheet_name, val, startRow = row, startCol = col)
          # Apply appropriate number format
          val_style <- get_value_style(metric_row$metric_name, styles)
          openxlsx::addStyle(wb, sheet_name, val_style, rows = row, cols = col)
        }
        col <- col + 1
      }
    }
    row <- row + 1

    # ---- vs Previous row ----
    openxlsx::writeData(wb, sheet_name, "  vs Prev", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet_name, styles$change_label, rows = row, cols = 1)

    col <- 2
    for (seg_name in segments) {
      seg_data <- metric_row$segments[[seg_name]]
      for (w_idx in seq_along(waves)) {
        wave_id <- waves[w_idx]

        if (w_idx == 1) {
          # No previous for first wave
          col <- col + 1
          next
        }

        change_val <- seg_data$change_vs_previous[[wave_id]]
        sig_val <- seg_data$sig_vs_previous[[wave_id]]

        if (!is.null(change_val) && !is.na(change_val)) {
          # Format: change value with arrow
          arrow <- format_sig_arrow(change_val, sig_val)
          display_val <- paste0(format_change_value(change_val, metric_row$metric_name), arrow)
          openxlsx::writeData(wb, sheet_name, display_val, startRow = row, startCol = col)

          # Style based on significance and direction
          change_style <- get_change_style(change_val, sig_val, styles)
          openxlsx::addStyle(wb, sheet_name, change_style, rows = row, cols = col)
        }
        col <- col + 1
      }
    }
    # Background for change row
    openxlsx::addStyle(wb, sheet_name, styles$change_row_bg,
                       rows = row, cols = 1:(1 + total_data_cols), gridExpand = TRUE, stack = TRUE)
    row <- row + 1

    # ---- vs Baseline row ----
    openxlsx::writeData(wb, sheet_name, "  vs Base", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet_name, styles$change_label, rows = row, cols = 1)

    col <- 2
    for (seg_name in segments) {
      seg_data <- metric_row$segments[[seg_name]]
      for (wave_id in waves) {
        if (wave_id == crosstab_data$baseline_wave) {
          col <- col + 1
          next
        }

        change_val <- seg_data$change_vs_baseline[[wave_id]]
        sig_val <- seg_data$sig_vs_baseline[[wave_id]]

        if (!is.null(change_val) && !is.na(change_val)) {
          arrow <- format_sig_arrow(change_val, sig_val)
          display_val <- paste0(format_change_value(change_val, metric_row$metric_name), arrow)
          openxlsx::writeData(wb, sheet_name, display_val, startRow = row, startCol = col)

          change_style <- get_change_style(change_val, sig_val, styles)
          openxlsx::addStyle(wb, sheet_name, change_style, rows = row, cols = col)
        }
        col <- col + 1
      }
    }
    openxlsx::addStyle(wb, sheet_name, styles$change_row_bg,
                       rows = row, cols = 1:(1 + total_data_cols), gridExpand = TRUE, stack = TRUE)
    row <- row + 1
  }

  # ---- Column widths ----
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 30)
  openxlsx::setColWidths(wb, sheet_name, cols = 2:(1 + total_data_cols), widths = 12)

  # ---- Freeze panes ----
  openxlsx::freezePane(wb, sheet_name, firstRow = TRUE, firstCol = TRUE,
                       firstActiveRow = 3, firstActiveCol = 2)
}


# ==============================================================================
# FORMATTING HELPERS
# ==============================================================================

#' Get Value Style Based on Metric Name
#' @keywords internal
get_value_style <- function(metric_name, styles) {
  if (metric_name %in% c("nps_score", "nps")) {
    styles$value_nps
  } else if (grepl("(pct|box|range|proportion|category|any)", metric_name)) {
    styles$value_percent
  } else {
    styles$value_number
  }
}

#' Format Change Value for Display
#' @keywords internal
format_change_value <- function(change_val, metric_name) {
  if (is.na(change_val)) return("")

  prefix <- if (change_val > 0) "+" else ""

  if (grepl("(pct|box|range|proportion|category|any)", metric_name)) {
    paste0(prefix, round(change_val * 100, 0), "pp")
  } else if (metric_name %in% c("nps_score", "nps")) {
    paste0(prefix, round(change_val, 0))
  } else {
    paste0(prefix, round(change_val, 1))
  }
}

#' Format Significance Arrow
#' @keywords internal
format_sig_arrow <- function(change_val, sig_val) {
  if (is.null(sig_val) || is.na(sig_val)) return("")

  if (isTRUE(sig_val)) {
    if (change_val > 0) return(" \u2191")  # ↑
    if (change_val < 0) return(" \u2193")  # ↓
    return(" \u2192")  # →
  }

  " \u2192"  # → for not significant
}

#' Get Change Style Based on Direction and Significance
#' @keywords internal
get_change_style <- function(change_val, sig_val, styles) {
  if (is.na(change_val)) return(styles$change_neutral)

  if (isTRUE(sig_val)) {
    if (change_val > 0) return(styles$sig_positive)
    if (change_val < 0) return(styles$sig_negative)
  }

  if (change_val > 0) return(styles$change_positive)
  if (change_val < 0) return(styles$change_negative)

  styles$change_neutral
}
