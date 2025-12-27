# ==============================================================================
# TurasTracker - Banner/Segment Output Functions
# ==============================================================================
#
# Banner and segment output functions extracted from tracker_output.R for
# improved maintainability and modularity.
#
# These functions handle writing Excel output for trend results with banner
# breakouts (segmented results where each segment appears as column groups).
#
# EXTRACTED FROM: modules/tracker/lib/tracker_output.R
# EXTRACTION DATE: 2025-12-27
# VERSION: 1.0.0
#
# DEPENDENCIES:
# - openxlsx: For Excel workbook creation and formatting
# - modules/shared/lib/formatting_utils.R: For create_excel_number_format()
# - modules/tracker/lib/tracker_output_styles.R: For Excel style objects
# - modules/tracker/lib/tracker_output_tables.R: For write_distribution_table()
#
# REQUIRED FUNCTIONS (from parent modules):
# - get_setting(): Retrieve configuration settings
# - is_significant(): Check significance test results
#
# FUNCTIONS:
# - detect_banner_results(): Detect if results have banner format structure
# - write_trend_sheets_with_banners(): Create trend sheets with banner segments
# - write_banner_trend_table(): Write trend table with segments as columns
# - write_change_summary_sheet(): Create summary sheet of baseline changes
#
# ==============================================================================


#' Detect Banner Results Format
#'
#' Detects if trend_results contain banner breakouts (question → segment structure)
#' or simple results (question → result structure).
#'
#' @keywords internal
detect_banner_results <- function(trend_results) {

  if (length(trend_results) == 0) {
    return(FALSE)
  }

  # Get first question's results
  first_q <- trend_results[[1]]

  # Check if it's a list of segments
  # Banner format: list(Total = result, Male = result, Female = result)
  # Simple format: list(question_code = ..., wave_results = ...)

  # If it has question_code field at top level, it's simple format
  if ("question_code" %in% names(first_q)) {
    return(FALSE)
  }

  # If first element itself has question_code, it's banner format
  if (is.list(first_q) && length(first_q) > 0) {
    first_segment <- first_q[[1]]
    if (is.list(first_segment) && "question_code" %in% names(first_segment)) {
      return(TRUE)
    }
  }

  return(FALSE)
}


#' Write Trend Sheets with Banner Breakouts
#'
#' Creates trend sheets with banner segments as columns.
#'
#' @keywords internal
write_trend_sheets_with_banners <- function(wb, banner_results, config, styles) {

  message(paste0("  Writing ", length(banner_results), " trend sheets with banner breakouts..."))

  wave_ids <- config$waves$WaveID

  for (q_code in names(banner_results)) {
    question_segments <- banner_results[[q_code]]

    # Skip if no segments calculated
    if (length(question_segments) == 0) {
      message(paste0("    Skipping ", q_code, " (no segments calculated)"))
      next
    }

    # Get result from first segment to determine question type
    first_seg <- question_segments[[1]]

    # Create sheet
    sheet_name <- substr(q_code, 1, 31)
    sheet_name <- gsub("[\\[\\]\\*/\\\\?:]", "_", sheet_name)

    openxlsx::addWorksheet(wb, sheet_name)

    current_row <- 1

    # Question header
    openxlsx::writeData(wb, sheet_name, first_seg$question_code,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$title, rows = current_row, cols = 1)
    current_row <- current_row + 1

    openxlsx::writeData(wb, sheet_name, first_seg$question_text,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    current_row <- current_row + 2

    # Write banner trend table
    current_row <- write_banner_trend_table(wb, sheet_name, question_segments, wave_ids, config, styles, current_row)

    # Add distribution table for Total segment (rating questions only)
    if ("Total" %in% names(question_segments)) {
      total_result <- question_segments[["Total"]]
      current_row <- current_row + 1
      current_row <- write_distribution_table(wb, sheet_name, total_result, wave_ids, config, styles, current_row)
    }
  }
}


#' Write Banner Trend Table
#'
#' Writes trend table with segments as column groups.
#'
#' @keywords internal
write_banner_trend_table <- function(wb, sheet_name, question_segments, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  segment_names <- names(question_segments)
  first_seg <- question_segments[[1]]

  # Build column headers: Metric | W1_Total | W2_Total | W1_Male | W2_Male | ...
  headers <- c("Metric")
  for (seg_name in segment_names) {
    for (wave_id in wave_ids) {
      headers <- c(headers, paste0(wave_id, "_", seg_name))
    }
  }

  # Write headers
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write metric rows based on question type
  if (first_seg$metric_type == "mean" || first_seg$metric_type == "composite") {
    # Mean row - write label and numbers separately
    openxlsx::writeData(wb, sheet_name, "Mean",
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values (rounded)
    num_cols <- length(segment_names) * length(wave_ids)
    mean_values <- numeric(num_cols)
    idx <- 1
    for (seg_name in segment_names) {
      seg_result <- question_segments[[seg_name]]
      for (wave_id in wave_ids) {
        wave_result <- seg_result$wave_results[[wave_id]]
        if (wave_result$available) {
          mean_values[idx] <- round(wave_result$mean, decimal_places)
        } else {
          mean_values[idx] <- NA_real_
        }
        idx <- idx + 1
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(mean_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:length(headers), gridExpand = TRUE, stack = TRUE)
    current_row <- current_row + 1

  } else if (first_seg$metric_type == "rating_enhanced" || first_seg$metric_type == "composite_enhanced") {
    # Enhanced metrics - write row for each metric in tracking_specs
    for (metric_name in first_seg$tracking_specs) {
      metric_lower <- tolower(trimws(metric_name))

      # Skip distribution (too complex for banner table)
      if (metric_lower == "distribution") {
        next
      }

      # Clean metric name for display
      display_name <- if (startsWith(metric_lower, "range:")) {
        paste0("% ", sub("range:", "", metric_name))
      } else if (metric_lower == "mean") {
        "Mean"
      } else if (metric_lower == "top_box") {
        "Top Box %"
      } else if (metric_lower == "top2_box") {
        "Top 2 Box %"
      } else if (metric_lower == "top3_box") {
        "Top 3 Box %"
      } else if (metric_lower == "bottom_box") {
        "Bottom Box %"
      } else if (metric_lower == "bottom2_box") {
        "Bottom 2 Box %"
      } else {
        metric_name
      }

      # Write label
      openxlsx::writeData(wb, sheet_name, display_name,
                          startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

      # Collect numeric values
      num_cols <- length(segment_names) * length(wave_ids)
      metric_values <- numeric(num_cols)
      idx <- 1
      for (seg_name in segment_names) {
        seg_result <- question_segments[[seg_name]]
        for (wave_id in wave_ids) {
          wave_result <- seg_result$wave_results[[wave_id]]
          if (wave_result$available && !is.null(wave_result$metrics)) {
            metric_val <- wave_result$metrics[[metric_lower]]
            if (!is.null(metric_val) && is.numeric(metric_val)) {
              metric_values[idx] <- round(metric_val, decimal_places)
            } else {
              metric_values[idx] <- NA_real_
            }
          } else {
            metric_values[idx] <- NA_real_
          }
          idx <- idx + 1
        }
      }

      # Write numeric values
      openxlsx::writeData(wb, sheet_name, t(metric_values),
                          startRow = current_row, startCol = 2, colNames = FALSE)

      # Apply number format
      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:length(headers), gridExpand = TRUE, stack = TRUE)
      current_row <- current_row + 1
    }

  } else if (first_seg$metric_type == "proportions") {
    # Proportions - write row for each response code
    for (code in first_seg$response_codes) {
      # Write label
      openxlsx::writeData(wb, sheet_name, as.character(code),
                          startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

      # Collect numeric values
      num_cols <- length(segment_names) * length(wave_ids)
      code_values <- numeric(num_cols)
      idx <- 1
      for (seg_name in segment_names) {
        seg_result <- question_segments[[seg_name]]
        for (wave_id in wave_ids) {
          wave_result <- seg_result$wave_results[[wave_id]]

          if (wave_result$available && !is.null(wave_result$proportions)) {
            pct <- wave_result$proportions[[as.character(code)]]
            code_values[idx] <- if (!is.null(pct) && !is.na(pct)) round(pct, decimal_places) else NA_real_
          } else {
            code_values[idx] <- NA_real_
          }
          idx <- idx + 1
        }
      }

      # Write numeric values
      openxlsx::writeData(wb, sheet_name, t(code_values),
                          startRow = current_row, startCol = 2, colNames = FALSE)

      # Apply number format
      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:length(headers), gridExpand = TRUE, stack = TRUE)
      current_row <- current_row + 1
    }

  } else if (first_seg$metric_type == "nps") {
    # NPS rows
    metrics <- c("NPS Score", "% Promoters", "% Passives", "% Detractors")

    for (metric in metrics) {
      # Write label
      openxlsx::writeData(wb, sheet_name, metric,
                          startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

      # Collect numeric values
      num_cols <- length(segment_names) * length(wave_ids)
      metric_values <- numeric(num_cols)
      idx <- 1
      for (seg_name in segment_names) {
        seg_result <- question_segments[[seg_name]]
        for (wave_id in wave_ids) {
          wave_result <- seg_result$wave_results[[wave_id]]

          if (wave_result$available) {
            val <- if (metric == "NPS Score") {
              wave_result$nps
            } else if (metric == "% Promoters") {
              wave_result$promoters_pct
            } else if (metric == "% Passives") {
              wave_result$passives_pct
            } else {
              wave_result$detractors_pct
            }
            metric_values[idx] <- round(val, decimal_places)
          } else {
            metric_values[idx] <- NA_real_
          }
          idx <- idx + 1
        }
      }

      # Write numeric values
      openxlsx::writeData(wb, sheet_name, t(metric_values),
                          startRow = current_row, startCol = 2, colNames = FALSE)

      # Apply number format
      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:length(headers), gridExpand = TRUE, stack = TRUE)
      current_row <- current_row + 1
    }
  }

  # Sample size row - write label and numbers separately
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  # Collect numeric values
  num_cols <- length(segment_names) * length(wave_ids)
  n_values <- numeric(num_cols)
  idx <- 1
  for (seg_name in segment_names) {
    seg_result <- question_segments[[seg_name]]
    for (wave_id in wave_ids) {
      wave_result <- seg_result$wave_results[[wave_id]]
      if (wave_result$available) {
        n_values[idx] <- wave_result$n_unweighted
      } else {
        n_values[idx] <- NA_real_
      }
      idx <- idx + 1
    }
  }

  # Write numeric values
  openxlsx::writeData(wb, sheet_name, t(n_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                    rows = current_row, cols = 2:length(headers), gridExpand = TRUE)
  current_row <- current_row + 2

  # Add changes section for Total segment
  if ("Total" %in% segment_names && length(wave_ids) > 1) {
    total_result <- question_segments[["Total"]]

    if (!is.null(total_result$changes) && length(total_result$changes) > 0) {

      # Determine changes structure (flat or nested by metric)
      first_change_item <- total_result$changes[[1]]
      is_nested <- is.list(first_change_item) && !("from_wave" %in% names(first_change_item))

      # For proportions, show ALL response codes; for enhanced metrics, show first metric only
      changes_to_show <- if (is_nested) {
        if (total_result$metric_type == "proportions") {
          # Show all response codes for proportions
          total_result$changes
        } else {
          # Use first metric's changes for other enhanced metrics (typically "mean")
          metric_name <- names(total_result$changes)[1]
          total_result$changes[[metric_name]]
        }
      } else {
        # Flat structure (old format)
        total_result$changes
      }

      if (length(changes_to_show) > 0) {
        # Changes header
        changes_header_text <- if (is_nested && total_result$metric_type != "proportions") {
          paste0("Wave-over-Wave Changes (Total - ", names(total_result$changes)[1], "):")
        } else {
          "Wave-over-Wave Changes (Total):"
        }
        openxlsx::writeData(wb, sheet_name, changes_header_text,
                            startRow = current_row, startCol = 1, colNames = FALSE)
        openxlsx::addStyle(wb, sheet_name, styles$header, rows = current_row, cols = 1)
        current_row <- current_row + 1

        # Changes table headers
        change_headers <- c("Comparison", "From", "To", "Change", "% Change", "Significant")
        openxlsx::writeData(wb, sheet_name, t(change_headers),
                            startRow = current_row, startCol = 1, colNames = FALSE)
        openxlsx::addStyle(wb, sheet_name, styles$wave_header,
                          rows = current_row, cols = 1:length(change_headers), gridExpand = TRUE)
        current_row <- current_row + 1

        # Get significance tests for the metric
        sig_tests <- if (is_nested && total_result$metric_type != "proportions") {
          metric_name <- names(total_result$changes)[1]
          total_result$significance[[metric_name]]
        } else {
          total_result$significance
        }

        # Write change rows
        for (change_name in names(changes_to_show)) {
          change <- changes_to_show[[change_name]]

          # For proportions, change is nested by response code, then by wave comparison
          # For other metrics, change is the wave comparison directly
          if (total_result$metric_type == "proportions" && is_nested) {
            # Nested by response code - iterate through wave comparisons for this code
            response_code <- change_name
            for (comp_name in names(change)) {
              comp <- change[[comp_name]]

              comparison_label <- paste0(comp$from_wave, " → ", comp$to_wave, " (", response_code, ")")

              # Get significance
              sig_key <- paste0(comp$from_wave, "_vs_", comp$to_wave)
              sig_test_for_code <- total_result$significance[[response_code]]
              sig_test <- if (!is.null(sig_test_for_code)) sig_test_for_code[[sig_key]] else NULL
              is_sig <- is_significant(sig_test)

              # Write label
              openxlsx::writeData(wb, sheet_name, comparison_label,
                                  startRow = current_row, startCol = 1, colNames = FALSE)

              # Write numeric values separately (rounded), checking for NA
              from_val <- if (!is.na(comp$from_value) && is.numeric(comp$from_value)) {
                round(comp$from_value, decimal_places)
              } else { NA_real_ }

              to_val <- if (!is.na(comp$to_value) && is.numeric(comp$to_value)) {
                round(comp$to_value, decimal_places)
              } else { NA_real_ }

              abs_change <- if (!is.na(comp$absolute_change) && is.numeric(comp$absolute_change)) {
                round(comp$absolute_change, decimal_places)
              } else { NA_real_ }

              pct_change <- if (!is.na(comp$percentage_change) && is.numeric(comp$percentage_change)) {
                round(comp$percentage_change, decimal_places)
              } else { NA_real_ }

              openxlsx::writeData(wb, sheet_name, from_val,
                                  startRow = current_row, startCol = 2, colNames = FALSE)
              openxlsx::writeData(wb, sheet_name, to_val,
                                  startRow = current_row, startCol = 3, colNames = FALSE)
              openxlsx::writeData(wb, sheet_name, abs_change,
                                  startRow = current_row, startCol = 4, colNames = FALSE)
              openxlsx::writeData(wb, sheet_name, pct_change,
                                  startRow = current_row, startCol = 5, colNames = FALSE)
              openxlsx::writeData(wb, sheet_name, if (is_sig) "Yes" else "No",
                                  startRow = current_row, startCol = 6, colNames = FALSE)

              # Apply number format
              number_style <- openxlsx::createStyle(numFmt = number_format)
              openxlsx::addStyle(wb, sheet_name, number_style,
                                rows = current_row, cols = 2:5, gridExpand = TRUE, stack = TRUE)
              current_row <- current_row + 1
            }
          } else {
            # Single level - change is the wave comparison directly

          comparison_label <- paste0(change$from_wave, " → ", change$to_wave)

          # Get significance
          sig_key <- paste0(change$from_wave, "_vs_", change$to_wave)
          sig_test <- sig_tests[[sig_key]]
          is_sig <- is_significant(sig_test)

          # Write label
          openxlsx::writeData(wb, sheet_name, comparison_label,
                              startRow = current_row, startCol = 1, colNames = FALSE)

          # Write numeric values separately (rounded), checking for NA
          from_val <- if (!is.na(change$from_value) && is.numeric(change$from_value)) {
            round(change$from_value, decimal_places)
          } else { NA_real_ }

          to_val <- if (!is.na(change$to_value) && is.numeric(change$to_value)) {
            round(change$to_value, decimal_places)
          } else { NA_real_ }

          abs_change <- if (!is.na(change$absolute_change) && is.numeric(change$absolute_change)) {
            round(change$absolute_change, decimal_places)
          } else { NA_real_ }

          pct_change <- if (!is.na(change$percentage_change) && is.numeric(change$percentage_change)) {
            round(change$percentage_change, decimal_places)
          } else { NA_real_ }

          openxlsx::writeData(wb, sheet_name, from_val,
                              startRow = current_row, startCol = 2, colNames = FALSE)
          openxlsx::writeData(wb, sheet_name, to_val,
                              startRow = current_row, startCol = 3, colNames = FALSE)
          openxlsx::writeData(wb, sheet_name, abs_change,
                              startRow = current_row, startCol = 4, colNames = FALSE)
          openxlsx::writeData(wb, sheet_name, pct_change,
                              startRow = current_row, startCol = 5, colNames = FALSE)
          openxlsx::writeData(wb, sheet_name, if (is_sig) "Yes" else "No",
                              startRow = current_row, startCol = 6, colNames = FALSE)

          # Apply number format
          number_style <- openxlsx::createStyle(numFmt = number_format)
          openxlsx::addStyle(wb, sheet_name, number_style,
                            rows = current_row, cols = 2:5, gridExpand = TRUE, stack = TRUE)

          # Style based on significance (is_sig is now guaranteed to be TRUE or FALSE)
          if (is_sig) {
            openxlsx::addStyle(wb, sheet_name, styles$significant,
                              rows = current_row, cols = 4:5, gridExpand = TRUE, stack = TRUE)
          }

          current_row <- current_row + 1
          }  # End else block for non-proportions metrics
        }
      }
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1:length(headers), widths = "auto")

  return(current_row + 1)
}


#' Write Change Summary Sheet
#'
#' Creates summary sheet showing all questions and their changes from baseline.
#'
#' @keywords internal
write_change_summary_sheet <- function(wb, banner_results, config, styles) {

  message("  Writing Change Summary sheet...")

  openxlsx::addWorksheet(wb, "Change_Summary")

  current_row <- 1

  # Title
  openxlsx::writeData(wb, "Change_Summary", "CHANGE SUMMARY - BASELINE COMPARISON",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, "Change_Summary", styles$title, rows = current_row, cols = 1)
  current_row <- current_row + 2

  wave_ids <- config$waves$WaveID
  baseline_wave <- wave_ids[1]  # Assume first wave is baseline
  latest_wave <- wave_ids[length(wave_ids)]

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Question", "Metric", "Baseline", "Latest", "Absolute Change", "% Change")
  openxlsx::writeData(wb, "Change_Summary", t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, "Change_Summary", styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write rows for each question (Total segment only for summary)
  for (q_code in names(banner_results)) {
    question_segments <- banner_results[[q_code]]

    # Get Total segment
    if ("Total" %in% names(question_segments)) {
      total_result <- question_segments[["Total"]]

      # Determine which metrics to show
      if (total_result$metric_type == "rating_enhanced" || total_result$metric_type == "composite_enhanced") {
        # Enhanced metrics - write a row for each tracked metric
        for (metric_spec in total_result$tracking_specs) {
          metric_lower <- tolower(trimws(metric_spec))

          # Skip distribution
          if (metric_lower == "distribution") {
            next
          }

          baseline_val <- NA
          latest_val <- NA

          # Get baseline and latest values from metrics list
          if (total_result$wave_results[[baseline_wave]]$available) {
            baseline_val <- total_result$wave_results[[baseline_wave]]$metrics[[metric_lower]]
          }
          if (total_result$wave_results[[latest_wave]]$available) {
            latest_val <- total_result$wave_results[[latest_wave]]$metrics[[metric_lower]]
          }

          # Calculate change
          abs_change <- NA
          pct_change <- NA
          if (!is.na(baseline_val) && !is.na(latest_val)) {
            abs_change <- latest_val - baseline_val
            if (baseline_val != 0) {
              pct_change <- (abs_change / baseline_val) * 100
            }
          }

          # Format metric name for display
          display_metric <- if (metric_lower == "mean") {
            "mean"
          } else if (metric_lower == "top_box") {
            "top_box"
          } else if (metric_lower == "top2_box") {
            "top2_box"
          } else if (metric_lower == "top3_box") {
            "top3_box"
          } else if (startsWith(metric_lower, "range:")) {
            metric_lower
          } else {
            metric_lower
          }

          # Write text columns
          openxlsx::writeData(wb, "Change_Summary", total_result$question_text,
                              startRow = current_row, startCol = 1, colNames = FALSE)
          openxlsx::writeData(wb, "Change_Summary", display_metric,
                              startRow = current_row, startCol = 2, colNames = FALSE)

          # Write numeric values separately (rounded)
          openxlsx::writeData(wb, "Change_Summary", round(baseline_val, decimal_places),
                              startRow = current_row, startCol = 3, colNames = FALSE)
          openxlsx::writeData(wb, "Change_Summary", round(latest_val, decimal_places),
                              startRow = current_row, startCol = 4, colNames = FALSE)
          openxlsx::writeData(wb, "Change_Summary", round(abs_change, decimal_places),
                              startRow = current_row, startCol = 5, colNames = FALSE)
          openxlsx::writeData(wb, "Change_Summary", round(pct_change, decimal_places),
                              startRow = current_row, startCol = 6, colNames = FALSE)

          # Apply number format to numeric columns (3-6)
          number_style <- openxlsx::createStyle(numFmt = number_format)
          openxlsx::addStyle(wb, "Change_Summary", number_style,
                            rows = current_row, cols = 3:6, gridExpand = TRUE, stack = TRUE)

          # Style change columns
          change_style <- if (!is.na(abs_change) && abs_change > 0) {
            styles$change_positive
          } else if (!is.na(abs_change) && abs_change < 0) {
            styles$change_negative
          } else {
            styles$data_number
          }

          openxlsx::addStyle(wb, "Change_Summary", change_style, rows = current_row, cols = 5:6, gridExpand = TRUE)

          current_row <- current_row + 1
        }

      } else {
        # Legacy metric types (mean, composite, nps)
        baseline_val <- NA
        latest_val <- NA

        # Get baseline and latest values
        if (total_result$metric_type == "mean" || total_result$metric_type == "composite") {
          if (total_result$wave_results[[baseline_wave]]$available) {
            baseline_val <- total_result$wave_results[[baseline_wave]]$mean
          }
          if (total_result$wave_results[[latest_wave]]$available) {
            latest_val <- total_result$wave_results[[latest_wave]]$mean
          }
        } else if (total_result$metric_type == "nps") {
          if (total_result$wave_results[[baseline_wave]]$available) {
            baseline_val <- total_result$wave_results[[baseline_wave]]$nps
          }
          if (total_result$wave_results[[latest_wave]]$available) {
            latest_val <- total_result$wave_results[[latest_wave]]$nps
          }
        }

        # Calculate change
        abs_change <- NA
        pct_change <- NA
        if (!is.na(baseline_val) && !is.na(latest_val)) {
          abs_change <- latest_val - baseline_val
          if (baseline_val != 0) {
            pct_change <- (abs_change / baseline_val) * 100
          }
        }

        # Write text columns
        openxlsx::writeData(wb, "Change_Summary", total_result$question_text,
                            startRow = current_row, startCol = 1, colNames = FALSE)
        openxlsx::writeData(wb, "Change_Summary", total_result$metric_type,
                            startRow = current_row, startCol = 2, colNames = FALSE)

        # Write numeric values separately (rounded)
        openxlsx::writeData(wb, "Change_Summary", round(baseline_val, decimal_places),
                            startRow = current_row, startCol = 3, colNames = FALSE)
        openxlsx::writeData(wb, "Change_Summary", round(latest_val, decimal_places),
                            startRow = current_row, startCol = 4, colNames = FALSE)
        openxlsx::writeData(wb, "Change_Summary", round(abs_change, decimal_places),
                            startRow = current_row, startCol = 5, colNames = FALSE)
        openxlsx::writeData(wb, "Change_Summary", round(pct_change, decimal_places),
                            startRow = current_row, startCol = 6, colNames = FALSE)

        # Apply number format to numeric columns (3-6)
        number_style <- openxlsx::createStyle(numFmt = number_format)
        openxlsx::addStyle(wb, "Change_Summary", number_style,
                          rows = current_row, cols = 3:6, gridExpand = TRUE, stack = TRUE)

        # Style change columns
        change_style <- if (!is.na(abs_change) && abs_change > 0) {
          styles$change_positive
        } else if (!is.na(abs_change) && abs_change < 0) {
          styles$change_negative
        } else {
          styles$data_number
        }

        openxlsx::addStyle(wb, "Change_Summary", change_style, rows = current_row, cols = 5:6, gridExpand = TRUE)

        current_row <- current_row + 1
      }
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Change_Summary", cols = 1:6, widths = c(40, 15, 12, 12, 15, 15))
}
