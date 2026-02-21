# ==============================================================================
# TurasTracker - Tracking Crosstab Excel Output
# ==============================================================================
#
# Writes the tracking crosstab data structure to a formatted Excel workbook.
# Layout follows traditional crosstab convention:
#   - 3-row header (banner group → segment → wave)
#   - Metrics grouped by question
#   - Per question: question header → base → % metrics → mean/NPS
#   - Change sub-rows (vs Prev, vs Base) under each metric
#
# VERSION: 2.0.0
# ==============================================================================


#' Write Tracking Crosstab Output
#'
#' Creates a formatted Excel workbook containing the tracking crosstab report.
#' Reads decimal settings from config for proper number formatting.
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
  styles <- create_crosstab_styles(config)

  # Sheet 1: Summary
  write_crosstab_summary_sheet(wb, crosstab_data, config, styles)

  # Sheet 2: Summary Data (flat filterable table)
  write_summary_data_sheet(wb, crosstab_data, config, styles)

  # Sheet 3: Tracking Crosstab
  write_crosstab_data_sheet(wb, crosstab_data, config, styles)

  # Save workbook
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  cat(paste0("  Tracking Crosstab saved to: ", output_path, "\n"))

  return(output_path)
}


#' Create Crosstab Excel Styles
#'
#' Creates styles with number formats driven by config decimal settings.
#'
#' @param config List. Configuration object (uses decimal_places_* settings)
#' @keywords internal
create_crosstab_styles <- function(config = NULL) {

  # Read decimal settings from config
  dp_ratings <- if (!is.null(config)) get_setting(config, "decimal_places_ratings", default = 2) else 2
  dp_pct <- if (!is.null(config)) get_setting(config, "decimal_places_percentages", default = 0) else 0
  dp_nps <- if (!is.null(config)) get_setting(config, "decimal_places_nps", default = 2) else 2

  # Ensure numeric
  dp_ratings <- as.integer(dp_ratings)
  dp_pct <- as.integer(dp_pct)
  dp_nps <- as.integer(dp_nps)

  # Build Excel numFmt codes using shared utility
  fmt_ratings <- create_excel_number_format(dp_ratings)
  fmt_pct <- create_excel_number_format(dp_pct)
  fmt_nps <- create_excel_number_format(dp_nps)

  list(
    # --- Header styles ---
    title = openxlsx::createStyle(
      fontSize = 14, textDecoration = "bold", halign = "left"
    ),
    banner_group = openxlsx::createStyle(
      fontSize = 11, textDecoration = "bold", halign = "center", valign = "center",
      fgFill = "#4472C4", fontColour = "#FFFFFF",
      border = "TopBottomLeftRight", borderColour = "#D9E2F3"
    ),
    segment_header = openxlsx::createStyle(
      fontSize = 10, textDecoration = "bold", halign = "center", valign = "center",
      fgFill = "#4472C4", fontColour = "#FFFFFF",
      border = "TopBottomLeftRight", borderColour = "#D9E2F3"
    ),
    wave_header = openxlsx::createStyle(
      fontSize = 10, textDecoration = "bold", halign = "center",
      fgFill = "#D9E2F3", border = "TopBottomLeftRight"
    ),

    # --- Question / section styles ---
    question_header = openxlsx::createStyle(
      fontSize = 11, textDecoration = "bold", halign = "left",
      fgFill = "#E2EFDA", border = "Bottom"
    ),
    section_header = openxlsx::createStyle(
      fontSize = 11, textDecoration = "bold", halign = "left",
      fgFill = "#C6EFCE", border = "Bottom", fontColour = "#006100"
    ),

    # --- Row label styles ---
    metric_label = openxlsx::createStyle(
      fontSize = 10, halign = "left", valign = "center",
      indent = 1
    ),
    change_label = openxlsx::createStyle(
      fontSize = 9, halign = "left", valign = "center",
      indent = 2, fontColour = "#666666"
    ),

    # --- Value styles (config-driven decimal places) ---
    value_rating = openxlsx::createStyle(
      fontSize = 10, halign = "center", numFmt = fmt_ratings,
      textDecoration = "bold"
    ),
    value_percent = openxlsx::createStyle(
      fontSize = 10, halign = "center", numFmt = fmt_pct
    ),
    value_nps = openxlsx::createStyle(
      fontSize = 10, halign = "center", numFmt = fmt_nps,
      textDecoration = "bold"
    ),
    base_row = openxlsx::createStyle(
      fontSize = 10, halign = "center", fontColour = "#666666", numFmt = "0"
    ),
    base_label = openxlsx::createStyle(
      fontSize = 10, halign = "left", valign = "center",
      indent = 1, fontColour = "#666666"
    ),

    # --- Change row styles ---
    change_row_bg = openxlsx::createStyle(
      fgFill = "#F5F5F5"
    ),
    change_neutral = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#999999"
    ),
    change_positive = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#548235"
    ),
    change_negative = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#C00000"
    ),

    # --- Significant change styles (bold + tinted background) ---
    sig_positive = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#006100",
      textDecoration = "bold", fgFill = "#E2EFDA"
    ),
    sig_negative = openxlsx::createStyle(
      fontSize = 9, halign = "center", fontColour = "#9C0006",
      textDecoration = "bold", fgFill = "#FFC7CE"
    ),

    # --- Info styles ---
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
    c("Base (n=)", "Unweighted sample size"),
    c("vs Prev", "Change compared to previous wave"),
    c("vs Base", paste0("Change compared to baseline (", crosstab_data$baseline_wave, ")")),
    c("pp", "Percentage points change"),
    c("*", "Statistically significant change"),
    c("Bold green bg", "Significant positive change"),
    c("Bold red bg", "Significant negative change"),
    c("Green text", "Non-significant positive change"),
    c("Red text", "Non-significant negative change")
  )
  for (item in legend_items) {
    openxlsx::writeData(wb, sheet_name, item[1], startRow = row, startCol = 1)
    openxlsx::writeData(wb, sheet_name, item[2], startRow = row, startCol = 2)
    row <- row + 1
  }

  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 20)
  openxlsx::setColWidths(wb, sheet_name, cols = 2, widths = 60)
}


#' Write Summary Data Sheet (Flat Filterable Table)
#'
#' Creates a flat table of metrics with columns:
#'   Section | Question | Metric Type | Seg1:Wave1 | Seg1:Wave2 | ... | SegN:WaveN
#'
#' The first data row below the header contains the base (n=) per column.
#' Section and Question are repeated on every row to support Excel filtering.
#'
#' @keywords internal
write_summary_data_sheet <- function(wb, crosstab_data, config, styles) {
  sheet_name <- "Summary Data"
  openxlsx::addWorksheet(wb, sheet_name)

  waves <- crosstab_data$waves
  wave_labels <- crosstab_data$wave_labels
  segments <- crosstab_data$banner_segments
  n_waves <- length(waves)
  n_segments <- length(segments)

  # ---- Build column headers ----
  # Fixed columns: Section, Question, Metric
  fixed_cols <- c("Section", "Question", "Metric")
  n_fixed <- length(fixed_cols)

  # Data columns: one per segment × wave
  data_col_headers <- character(0)
  for (seg_name in segments) {
    for (w_idx in seq_along(waves)) {
      if (n_segments == 1 && seg_name == "Total") {
        # Single segment: just wave label
        data_col_headers <- c(data_col_headers, wave_labels[w_idx])
      } else {
        # Multiple segments: "Segment - Wave"
        data_col_headers <- c(data_col_headers, paste0(seg_name, " - ", wave_labels[w_idx]))
      }
    }
  }

  all_headers <- c(fixed_cols, data_col_headers)
  n_cols <- length(all_headers)

  # ---- Write header row ----
  row <- 1
  for (c_idx in seq_along(all_headers)) {
    openxlsx::writeData(wb, sheet_name, all_headers[c_idx], startRow = row, startCol = c_idx)
  }

  # Style headers
  header_style <- openxlsx::createStyle(
    fontSize = 10, textDecoration = "bold", halign = "center",
    fgFill = "#4472C4", fontColour = "#FFFFFF",
    border = "TopBottomLeftRight", borderColour = "#D9E2F3"
  )
  openxlsx::addStyle(wb, sheet_name, header_style,
                     rows = row, cols = 1:n_cols, gridExpand = TRUE)
  row <- row + 1

  # ---- Base (n=) row ----
  # Use the first metric's n values (shared across metrics within each question)
  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 1)
  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 2)
  openxlsx::writeData(wb, sheet_name, "Base (n=)", startRow = row, startCol = 3)

  # For base row, use the first metric of each question group to get representative n
  # Since base can vary by question, write the overall first metric's n
  first_metric <- crosstab_data$metrics[[1]]
  col <- n_fixed + 1
  for (seg_name in segments) {
    seg_data <- first_metric$segments[[seg_name]]
    for (wave_id in waves) {
      n_val <- seg_data$n[[wave_id]]
      if (!is.null(n_val) && !is.na(n_val)) {
        openxlsx::writeData(wb, sheet_name, n_val, startRow = row, startCol = col)
      }
      col <- col + 1
    }
  }
  openxlsx::addStyle(wb, sheet_name, styles$base_row,
                     rows = row, cols = (n_fixed + 1):n_cols, gridExpand = TRUE)
  openxlsx::addStyle(wb, sheet_name, styles$base_label,
                     rows = row, cols = 1:n_fixed, gridExpand = TRUE)
  row <- row + 1

  # ---- Group metrics by question, sort within question by traditional order ----
  question_groups <- group_metrics_by_question(crosstab_data$metrics)

  for (q_group in question_groups) {
    first_metric <- q_group[[1]]
    q_section <- if (is.na(first_metric$section) || first_metric$section == "") {
      "(Ungrouped)"
    } else {
      first_metric$section
    }
    q_text <- if (!is.null(first_metric$question_text) &&
                   !is.na(first_metric$question_text) &&
                   nzchar(trimws(first_metric$question_text))) {
      first_metric$question_text
    } else {
      first_metric$question_code
    }

    sorted_metrics <- sort_metrics_traditional(q_group)

    for (metric_row in sorted_metrics) {
      metric_suffix <- get_metric_suffix(metric_row$metric_name)

      # Write fixed columns: Section, Question, Metric (repeated per row for filtering)
      openxlsx::writeData(wb, sheet_name, q_section, startRow = row, startCol = 1)
      openxlsx::writeData(wb, sheet_name, q_text, startRow = row, startCol = 2)
      openxlsx::writeData(wb, sheet_name, metric_suffix, startRow = row, startCol = 3)

      # Write data values per segment × wave
      col <- n_fixed + 1
      for (seg_name in segments) {
        seg_data <- metric_row$segments[[seg_name]]
        for (wave_id in waves) {
          val <- seg_data$values[[wave_id]]
          if (!is.na(val)) {
            openxlsx::writeData(wb, sheet_name, val, startRow = row, startCol = col)
            val_style <- get_value_style(metric_row$metric_name, styles)
            openxlsx::addStyle(wb, sheet_name, val_style, rows = row, cols = col)
          }
          col <- col + 1
        }
      }
      row <- row + 1
    }
  }

  # ---- Column widths ----
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 20)   # Section
  openxlsx::setColWidths(wb, sheet_name, cols = 2, widths = 45)   # Question
  openxlsx::setColWidths(wb, sheet_name, cols = 3, widths = 15)   # Metric
  if (n_cols > n_fixed) {
    openxlsx::setColWidths(wb, sheet_name, cols = (n_fixed + 1):n_cols, widths = 12)
  }

  # Freeze header row and fixed columns
  openxlsx::freezePane(wb, sheet_name, firstActiveRow = 2, firstActiveCol = n_fixed + 1)

  # Add auto-filter
  openxlsx::addFilter(wb, sheet_name, rows = 1, cols = 1:n_cols)
}


#' Write Tracking Crosstab Data Sheet
#'
#' Traditional crosstab layout:
#' - 3-row headers (banner group → segment → wave)
#' - Metrics grouped by question
#' - Per question: question header → base → % metrics → mean/NPS → change sub-rows
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

  # Column layout: Col 1 = labels, Col 2 = metric type, then data columns
  label_cols <- 2
  total_data_cols <- n_segments * n_waves
  all_cols <- label_cols + total_data_cols

  # ===========================================================================
  # 3-ROW HEADER
  # ===========================================================================
  row <- 1

  # ---- Row 1: Banner group labels ----
  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 1)
  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 2)
  openxlsx::addStyle(wb, sheet_name, styles$banner_group, rows = row, cols = 1:label_cols, gridExpand = TRUE)

  col <- label_cols + 1
  for (seg_idx in seq_along(segments)) {
    seg_name <- segments[seg_idx]
    start_col <- col
    end_col <- col + n_waves - 1

    # For "Total" the group is "Total"; for banner segments, use segment name as group
    openxlsx::writeData(wb, sheet_name, seg_name, startRow = row, startCol = start_col)
    if (n_waves > 1) {
      openxlsx::mergeCells(wb, sheet_name, cols = start_col:end_col, rows = row)
    }
    openxlsx::addStyle(wb, sheet_name, styles$banner_group,
                       rows = row, cols = start_col:end_col, gridExpand = TRUE)
    col <- end_col + 1
  }
  row <- row + 1

  # ---- Row 2: Segment option labels ----
  openxlsx::writeData(wb, sheet_name, "Question", startRow = row, startCol = 1)
  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 2)
  openxlsx::addStyle(wb, sheet_name, styles$segment_header, rows = row, cols = 1:label_cols, gridExpand = TRUE)

  col <- label_cols + 1
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

  # ---- Row 3: Wave labels ----
  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 1)
  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 2)
  openxlsx::addStyle(wb, sheet_name, styles$wave_header, rows = row, cols = 1:label_cols, gridExpand = TRUE)

  col <- label_cols + 1
  for (seg_idx in seq_along(segments)) {
    for (w_idx in seq_along(waves)) {
      openxlsx::writeData(wb, sheet_name, wave_labels[w_idx], startRow = row, startCol = col)
      openxlsx::addStyle(wb, sheet_name, styles$wave_header, rows = row, cols = col)
      col <- col + 1
    }
  }
  row <- row + 1

  # ===========================================================================
  # DATA ROWS — Group metrics by question, traditional crosstab ordering
  # ===========================================================================

  # Group metrics by question_code (preserving order)
  question_groups <- group_metrics_by_question(crosstab_data$metrics)

  current_section <- ""

  for (q_group in question_groups) {
    first_metric <- q_group[[1]]

    # ---- Section divider (if section changed) ----
    metric_section <- first_metric$section
    if (is.na(metric_section) || metric_section == "") metric_section <- "(Ungrouped)"

    if (metric_section != current_section) {
      current_section <- metric_section
      openxlsx::writeData(wb, sheet_name, current_section, startRow = row, startCol = 1)
      openxlsx::mergeCells(wb, sheet_name, cols = 1:all_cols, rows = row)
      openxlsx::addStyle(wb, sheet_name, styles$section_header,
                         rows = row, cols = 1:all_cols, gridExpand = TRUE)
      row <- row + 1
    }

    # ---- Question header row ----
    question_display <- if (!is.null(first_metric$question_text) &&
                            !is.na(first_metric$question_text) &&
                            nzchar(trimws(first_metric$question_text))) {
      first_metric$question_text
    } else {
      first_metric$question_code
    }

    openxlsx::writeData(wb, sheet_name, question_display, startRow = row, startCol = 1)
    openxlsx::mergeCells(wb, sheet_name, cols = 1:all_cols, rows = row)
    openxlsx::addStyle(wb, sheet_name, styles$question_header,
                       rows = row, cols = 1:all_cols, gridExpand = TRUE)
    row <- row + 1

    # ---- Base (n=) row (shared — use first metric's n values) ----
    openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 1)
    openxlsx::writeData(wb, sheet_name, "Base (n=)", startRow = row, startCol = 2)
    openxlsx::addStyle(wb, sheet_name, styles$base_label, rows = row, cols = 1:label_cols, gridExpand = TRUE)

    col <- label_cols + 1
    for (seg_name in segments) {
      seg_data <- first_metric$segments[[seg_name]]
      for (wave_id in waves) {
        n_val <- seg_data$n[[wave_id]]
        if (!is.null(n_val) && !is.na(n_val)) {
          openxlsx::writeData(wb, sheet_name, n_val, startRow = row, startCol = col)
          openxlsx::addStyle(wb, sheet_name, styles$base_row, rows = row, cols = col)
        }
        col <- col + 1
      }
    }
    row <- row + 1

    # ---- Sort metrics: percentages first, then means/NPS ----
    sorted_metrics <- sort_metrics_traditional(q_group)

    # ---- Metric rows ----
    for (metric_row in sorted_metrics) {
      metric_suffix <- get_metric_suffix(metric_row$metric_name)

      # Value row
      openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 1)
      openxlsx::writeData(wb, sheet_name, metric_suffix, startRow = row, startCol = 2)
      openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = row, cols = 1:label_cols, gridExpand = TRUE)

      col <- label_cols + 1
      for (seg_name in segments) {
        seg_data <- metric_row$segments[[seg_name]]
        for (wave_id in waves) {
          val <- seg_data$values[[wave_id]]
          if (!is.na(val)) {
            openxlsx::writeData(wb, sheet_name, val, startRow = row, startCol = col)
            val_style <- get_value_style(metric_row$metric_name, styles)
            openxlsx::addStyle(wb, sheet_name, val_style, rows = row, cols = col)
          }
          col <- col + 1
        }
      }
      row <- row + 1

      # vs Previous row
      row <- write_change_row(wb, sheet_name, "vs Prev", metric_row, segments, waves,
                               crosstab_data$baseline_wave, "previous", styles,
                               label_cols, all_cols, row)

      # vs Baseline row
      row <- write_change_row(wb, sheet_name, "vs Base", metric_row, segments, waves,
                               crosstab_data$baseline_wave, "baseline", styles,
                               label_cols, all_cols, row)
    }

    # ---- Blank separator row between question blocks ----
    row <- row + 1
  }

  # ===========================================================================
  # COLUMN WIDTHS AND FREEZE
  # ===========================================================================
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 45)  # Question text
  openxlsx::setColWidths(wb, sheet_name, cols = 2, widths = 15)  # Metric type
  openxlsx::setColWidths(wb, sheet_name, cols = (label_cols + 1):(label_cols + total_data_cols), widths = 10)

  # Freeze after 3 header rows and 2 label columns
  openxlsx::freezePane(wb, sheet_name, firstActiveRow = 4, firstActiveCol = 3)
}


#' Write a Change Sub-Row (vs Prev or vs Base)
#'
#' @param change_type Character. "previous" or "baseline"
#' @return Integer. The next row number
#' @keywords internal
write_change_row <- function(wb, sheet_name, label, metric_row, segments, waves,
                              baseline_wave, change_type, styles,
                              label_cols, all_cols, row) {

  openxlsx::writeData(wb, sheet_name, "", startRow = row, startCol = 1)
  openxlsx::writeData(wb, sheet_name, label, startRow = row, startCol = 2)
  openxlsx::addStyle(wb, sheet_name, styles$change_label, rows = row, cols = 1:label_cols, gridExpand = TRUE)

  col <- label_cols + 1
  for (seg_name in segments) {
    seg_data <- metric_row$segments[[seg_name]]
    for (w_idx in seq_along(waves)) {
      wave_id <- waves[w_idx]

      # Skip: first wave for vs_previous, baseline wave for vs_baseline
      skip <- if (change_type == "previous") {
        w_idx == 1
      } else {
        wave_id == baseline_wave
      }

      if (skip) {
        col <- col + 1
        next
      }

      change_list <- if (change_type == "previous") seg_data$change_vs_previous else seg_data$change_vs_baseline
      sig_list <- if (change_type == "previous") seg_data$sig_vs_previous else seg_data$sig_vs_baseline

      change_val <- change_list[[wave_id]]
      sig_val <- sig_list[[wave_id]]

      if (!is.null(change_val) && !is.na(change_val)) {
        display_val <- format_change_with_sig(change_val, sig_val, metric_row$metric_name)
        openxlsx::writeData(wb, sheet_name, display_val, startRow = row, startCol = col)

        change_style <- get_change_style(change_val, sig_val, styles)
        openxlsx::addStyle(wb, sheet_name, change_style, rows = row, cols = col)
      }
      col <- col + 1
    }
  }

  # Background for change row
  openxlsx::addStyle(wb, sheet_name, styles$change_row_bg,
                     rows = row, cols = 1:all_cols, gridExpand = TRUE, stack = TRUE)

  row + 1
}


# ==============================================================================
# QUESTION GROUPING AND SORTING
# ==============================================================================

#' Group Metrics by Question Code
#'
#' Groups the flat list of metric_rows into sub-lists by question_code,
#' preserving the original order of first appearance.
#'
#' @param metrics List of metric_row objects
#' @return List of lists, each sub-list containing metrics for one question
#' @keywords internal
group_metrics_by_question <- function(metrics) {
  if (length(metrics) == 0) return(list())

  groups <- list()
  seen_codes <- character(0)

  for (m in metrics) {
    q_code <- m$question_code
    if (q_code %in% seen_codes) {
      # Append to existing group
      idx <- which(vapply(groups, function(g) g[[1]]$question_code, character(1)) == q_code)
      groups[[idx]] <- c(groups[[idx]], list(m))
    } else {
      # New group
      seen_codes <- c(seen_codes, q_code)
      groups[[length(groups) + 1]] <- list(m)
    }
  }

  groups
}


#' Sort Metrics Within a Question Group (Traditional Crosstab Order)
#'
#' Orders: percentages first, then means/ratings, then NPS.
#'
#' @keywords internal
sort_metrics_traditional <- function(q_group) {
  # Assign priority: lower = first
  get_priority <- function(metric_name) {
    if (grepl("(pct|box|range|proportion|category|any|top.*_box|bottom.*_box)", metric_name)) return(1)  # Percentages
    if (metric_name %in% c("mean", "sd")) return(2)  # Mean/SD
    if (metric_name %in% c("nps_score", "nps", "promoters_pct", "passives_pct", "detractors_pct")) return(3)  # NPS
    2  # Default: treat as mean
  }

  priorities <- vapply(q_group, function(m) get_priority(m$metric_name), numeric(1))
  sort_orders <- vapply(q_group, function(m) m$sort_order, numeric(1))

  # Sort by priority first, then by original sort_order
  idx <- order(priorities, sort_orders)
  q_group[idx]
}


# ==============================================================================
# FORMATTING HELPERS
# ==============================================================================

#' Get Human-Readable Metric Suffix
#'
#' Returns a short label for the metric column based on metric name.
#'
#' @keywords internal
get_metric_suffix <- function(metric_name) {
  if (metric_name == "mean") return("Mean")
  if (metric_name == "top_box") return("Top Box %")
  if (metric_name == "top2_box") return("Top 2 Box %")
  if (metric_name == "top3_box") return("Top 3 Box %")
  if (metric_name == "bottom_box") return("Bottom Box %")
  if (metric_name == "bottom2_box") return("Bottom 2 Box %")
  if (metric_name %in% c("nps_score", "nps")) return("NPS")
  if (metric_name == "promoters_pct") return("% Promoters")
  if (metric_name == "passives_pct") return("% Passives")
  if (metric_name == "detractors_pct") return("% Detractors")
  if (metric_name == "any") return("% Any")
  if (metric_name == "count_mean") return("Mean Count")

  # Pattern-based
  if (grepl("^box_", metric_name)) {
    label <- sub("^box_", "", metric_name)
    label <- gsub("_", " ", label)
    return(paste0("% ", tools::toTitleCase(label)))
  }
  if (grepl("^category_", metric_name)) {
    label <- sub("^category_", "", metric_name)
    label <- gsub("_", " ", label)
    return(paste0("% ", tools::toTitleCase(label)))
  }
  if (grepl("^range_", metric_name)) {
    range_part <- sub("^range_", "", metric_name)
    return(paste0("Range ", range_part, " %"))
  }

  # Fallback
  metric_name
}


#' Get Value Style Based on Metric Name
#' @keywords internal
get_value_style <- function(metric_name, styles) {
  if (metric_name %in% c("nps_score", "nps")) {
    styles$value_nps
  } else if (grepl("(pct|box|range|proportion|category|any|top.*_box|bottom.*_box)", metric_name)) {
    styles$value_percent
  } else {
    styles$value_rating
  }
}

#' Format Change Value for Display
#' @keywords internal
format_change_value <- function(change_val, metric_name) {
  if (is.na(change_val)) return("")

  prefix <- if (change_val > 0) "+" else ""

  if (grepl("(pct|box|range|proportion|category|any|top.*_box|bottom.*_box)", metric_name)) {
    # Values are already on 0-100 scale, so change is in percentage points
    paste0(prefix, round(change_val, 0), "pp")
  } else if (metric_name %in% c("nps_score", "nps")) {
    paste0(prefix, round(change_val, 0))
  } else {
    paste0(prefix, round(change_val, 2))
  }
}


#' Format Change with Significance Indicator
#'
#' Produces a compact display string like "+5pp *" for significant changes
#' or "+3pp" for non-significant.
#'
#' @keywords internal
format_change_with_sig <- function(change_val, sig_val, metric_name) {
  if (is.null(change_val) || is.na(change_val)) return("")

  change_str <- format_change_value(change_val, metric_name)

  if (isTRUE(sig_val)) {
    paste0(change_str, " *")
  } else {
    change_str
  }
}


#' Format Significance Arrow (kept for HTML report compatibility)
#' @keywords internal
format_sig_arrow <- function(change_val, sig_val) {
  if (is.null(sig_val) || is.na(sig_val)) return("")

  if (isTRUE(sig_val)) {
    if (change_val > 0) return(" \u2191")
    if (change_val < 0) return(" \u2193")
    return(" \u2192")
  }

  " \u2192"
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
