# ==============================================================================
# TurasTracker - Wave History Output Functions
# ==============================================================================
#
# EXTRACTED FROM: tracker_output.R
#
# PURPOSE:
# Contains specialized functions for generating Wave History Excel output format.
# Wave History format shows one row per question/metric with columns for each wave,
# making it easy to track metrics across time.
#
# MAINTAINABILITY NOTE:
# This file was extracted from tracker_output.R to improve modularity and
# maintainability. Keep wave history output logic isolated here.
#
# DEPENDENCIES:
# - openxlsx: Excel workbook creation and formatting
# - Tracker styles: create_tracker_styles() from tracker_output.R
# - Shared utilities: get_setting(), create_excel_number_format()
# - TRS utilities: turas_save_workbook_atomic(), turas_write_run_status_sheet()
# - Error handling: tracker_refuse() from tracker_utils.R
# - Result detection: detect_banner_results() from tracker_utils.R
#
# FUNCTIONS:
# - write_wave_history_output()    : Main entry point for wave history output
# - write_wave_history_sheet()     : Writes one sheet in wave history format
# - extract_wave_history_metrics() : Determines which metrics to track per question
# - extract_metric_value()         : Extracts metric values from wave results
#
# ==============================================================================


#' Write Wave History Output
#'
#' Creates an Excel workbook in Wave History format showing metrics across waves.
#' Each row represents one question/metric, with columns for each wave.
#'
#' @param trend_results List. Trend results from calculate_all_trends() or calculate_trends_with_banners()
#' @param config Configuration object
#' @param wave_data List of wave data frames
#' @param output_path Character. Path for output file
#' @param banner_segments List. Banner segment definitions (optional)
#' @return Character. Path to created file
#'
#' @export
write_wave_history_output <- function(trend_results, config, wave_data, output_path = NULL, banner_segments = NULL, run_result = NULL) {

  cat("\n================================================================================\n")
  cat("WRITING WAVE HISTORY EXCEL OUTPUT\n")
  cat("================================================================================\n\n")

  # Detect if results have banner breakouts
  has_banners <- detect_banner_results(trend_results)

  if (has_banners) {
    cat("  Detected banner breakout results\n")
  }

  # Determine output path
  if (is.null(output_path)) {
    # Get output directory from settings or use config file location
    output_dir <- get_setting(config, "output_dir", default = NULL)

    if (is.null(output_dir) || !nzchar(trimws(output_dir))) {
      # Default to same directory as config file
      output_dir <- dirname(config$config_path)
    }

    # Ensure output directory exists
    if (!dir.exists(output_dir)) {
      tryCatch({
        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      }, error = function(e) {
        warning(paste0("Could not create output directory: ", output_dir, ". Using config directory."))
        output_dir <<- dirname(config$config_path)
      })
    }

    # Check for output_file setting first, otherwise auto-generate
    output_file <- get_setting(config, "output_file", default = NULL)
    if (!is.null(output_file) && nzchar(trimws(output_file))) {
      filename <- trimws(output_file)
    } else {
      # Generate filename
      project_name <- get_setting(config, "project_name", default = "Tracking")
      project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)  # Sanitize
      filename <- paste0(project_name, "_WaveHistory_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    }

    # Combine directory and filename
    output_path <- file.path(output_dir, filename)
  }

  cat(paste0("Output file: ", output_path, "\n"))

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Create styles
  styles <- create_tracker_styles()

  # Get wave IDs for column headers
  wave_ids <- config$waves$WaveID

  # Write sheets based on result structure
  if (has_banners) {
    # Get segment names from first question's results
    first_q_result <- trend_results[[1]]
    segment_names <- names(first_q_result)

    # Write one sheet per segment
    for (seg_name in segment_names) {
      write_wave_history_sheet(wb, seg_name, trend_results, wave_ids, config, styles, segment_filter = seg_name)
    }
  } else {
    # Single "Total" sheet for simple results
    write_wave_history_sheet(wb, "Total", trend_results, wave_ids, config, styles, segment_filter = NULL)
  }

  # ===========================================================================
  # TRS v1.0: Add Run_Status Sheet
  # ===========================================================================
  if (!is.null(run_result) && exists("turas_write_run_status_sheet", mode = "function")) {
    turas_write_run_status_sheet(wb, run_result)
  }

  # Save workbook (TRS v1.0: Use atomic save if available)
  cat(paste0("\nSaving workbook...\n"))
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "TRACKER")
    if (!save_result$success) {
      tracker_refuse(
        code = "IO_SAVE_FAILED",
        title = "Excel Save Failed",
        problem = sprintf("Failed to save Excel file: %s", save_result$error),
        why_it_matters = "The tracker output could not be written to disk",
        how_to_fix = c("Check that the output directory exists and is writable",
                       "Ensure the file is not open in another program",
                       "Verify sufficient disk space is available"),
        details = list(output_path = output_path, error = save_result$error)
      )
    }
  } else {
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  }

  cat(paste0("\u2713 Wave History output written to: ", output_path, "\n"))
  cat("================================================================================\n\n")

  return(output_path)
}


#' Write Wave History Sheet
#'
#' Writes one sheet in Wave History format (one row per question/metric).
#'
#' @keywords internal
write_wave_history_sheet <- function(wb, sheet_name, trend_results, wave_ids, config, styles, segment_filter = NULL) {

  message(paste0("  Writing sheet: ", sheet_name))

  # Create sheet
  openxlsx::addWorksheet(wb, sheet_name)

  current_row <- 1

  # Header row 1: Segment label
  segment_label <- if (sheet_name == "Total") {
    "Total Sample"
  } else {
    paste0("Filter: ", sheet_name)
  }

  openxlsx::writeData(wb, sheet_name, segment_label,
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$title, rows = current_row, cols = 1)
  current_row <- current_row + 2

  # Column headers: QuestionCode | Question | Type | Wave 1 | Wave 2 | ...
  headers <- c("QuestionCode", "Question", "Type", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Base row: Show sample size (n) for each wave
  # Write label columns first
  openxlsx::writeData(wb, sheet_name, "", startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::writeData(wb, sheet_name, "BASE", startRow = current_row, startCol = 2, colNames = FALSE)
  openxlsx::writeData(wb, sheet_name, "n", startRow = current_row, startCol = 3, colNames = FALSE)

  # Collect sample sizes for each wave (as numeric)
  base_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_id <- wave_ids[i]
    # Get sample size from any available question's wave result
    n_value <- NA_real_

    # Try to get from any question result for this wave
    for (q_code in names(trend_results)) {
      q_result <- if (!is.null(segment_filter)) {
        # For banner segments, extract segment-specific result
        if (!is.null(trend_results[[q_code]]) && is.list(trend_results[[q_code]]) &&
            segment_filter %in% names(trend_results[[q_code]])) {
          trend_results[[q_code]][[segment_filter]]
        } else {
          NULL
        }
      } else {
        # For Total, extract main result
        trend_results[[q_code]]
      }

      # Check if we got valid result and extract n_unweighted
      if (!is.null(q_result) &&
          !is.null(q_result$wave_results) &&
          wave_id %in% names(q_result$wave_results)) {
        wave_result <- q_result$wave_results[[wave_id]]
        if (!is.null(wave_result) &&
            !is.null(wave_result$available) &&
            wave_result$available &&
            !is.null(wave_result$n_unweighted)) {
          n_value <- as.numeric(wave_result$n_unweighted)
          break  # Found a valid sample size, use it
        }
      }
    }

    base_values[i] <- n_value
  }

  # Write numeric base values
  openxlsx::writeData(wb, sheet_name, t(base_values),
                      startRow = current_row, startCol = 4, colNames = FALSE)

  # Style base row with bold font
  base_style <- openxlsx::createStyle(textDecoration = "bold", numFmt = "0")
  openxlsx::addStyle(wb, sheet_name, base_style,
                    rows = current_row, cols = 1:(3 + length(wave_ids)), gridExpand = TRUE)
  current_row <- current_row + 1

  # Get decimal separator and decimal places
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Write data rows - one row per question/metric
  for (q_code in names(trend_results)) {
    # Get result for this question
    q_result <- if (!is.null(segment_filter)) {
      # Banner results: extract segment
      trend_results[[q_code]][[segment_filter]]
    } else {
      # Simple results
      trend_results[[q_code]]
    }

    # Skip if segment not available for this question
    if (is.null(q_result)) {
      next
    }

    # Extract metrics to track based on question type
    metrics_to_track <- extract_wave_history_metrics(q_result)

    # Write one row for each metric
    for (metric_info in metrics_to_track) {
      # Write QuestionCode
      openxlsx::writeData(wb, sheet_name, q_result$question_code,
                          startRow = current_row, startCol = 1, colNames = FALSE)

      # Write Question text
      openxlsx::writeData(wb, sheet_name, q_result$question_text,
                          startRow = current_row, startCol = 2, colNames = FALSE)

      # Write Type (metric label)
      openxlsx::writeData(wb, sheet_name, metric_info$label,
                          startRow = current_row, startCol = 3, colNames = FALSE)

      # Extract wave values for this metric
      wave_values <- numeric(length(wave_ids))
      for (i in seq_along(wave_ids)) {
        wave_id <- wave_ids[i]
        wave_result <- q_result$wave_results[[wave_id]]

        if (!is.null(wave_result) && wave_result$available) {
          # Extract value based on metric type
          value <- extract_metric_value(wave_result, metric_info$metric_key, q_result$metric_type)
          # Ensure value is scalar before checking is.na
          wave_values[i] <- if (length(value) == 1 && !is.na(value)) round(value, decimal_places) else NA_real_
        } else {
          wave_values[i] <- NA_real_
        }
      }

      # Write wave values
      openxlsx::writeData(wb, sheet_name, t(wave_values),
                          startRow = current_row, startCol = 4, colNames = FALSE)

      # Apply number format to wave columns
      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 4:(3 + length(wave_ids)), gridExpand = TRUE, stack = TRUE)

      current_row <- current_row + 1
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 15)  # QuestionCode
  openxlsx::setColWidths(wb, sheet_name, cols = 2, widths = 60)  # Question
  openxlsx::setColWidths(wb, sheet_name, cols = 3, widths = 12)  # Type
  openxlsx::setColWidths(wb, sheet_name, cols = 4:(3 + length(wave_ids)), widths = 12)  # Waves
}


#' Extract Wave History Metrics
#'
#' Determines which metrics to track for a question in Wave History format.
#'
#' @keywords internal
extract_wave_history_metrics <- function(q_result) {
  metrics <- list()

  # Guard against NULL/empty metric_type
  metric_type <- q_result$metric_type
  if (is.null(metric_type) || length(metric_type) == 0 || !nzchar(metric_type)) {
    warning(paste0("Question ", q_result$question_code, " has no metric_type, skipping wave history"))
    return(metrics)  # Return empty list
  }

  if (metric_type == "rating_enhanced" || metric_type == "composite_enhanced") {
    # Enhanced metrics - use tracking_specs
    for (spec in q_result$tracking_specs) {
      spec_lower <- tolower(trimws(spec))

      # Skip distribution
      if (spec_lower == "distribution") {
        next
      }

      # Generate label
      label <- if (spec_lower == "mean") {
        "Mean"
      } else if (spec_lower == "top_box") {
        "Top Box"
      } else if (spec_lower == "top2_box") {
        "Top 2 Box"
      } else if (spec_lower == "top3_box") {
        "Top 3 Box"
      } else if (spec_lower == "bottom_box") {
        "Bottom Box"
      } else if (spec_lower == "bottom2_box") {
        "Bottom 2 Box"
      } else if (startsWith(spec_lower, "range:")) {
        paste0("% ", sub("range:", "", spec))
      } else {
        spec
      }

      metrics[[length(metrics) + 1]] <- list(
        metric_key = spec_lower,
        label = label
      )
    }

  } else if (metric_type == "mean" || metric_type == "composite") {
    # Simple mean
    metrics[[1]] <- list(metric_key = "mean", label = "Mean")

  } else if (metric_type == "nps") {
    # NPS score
    metrics[[1]] <- list(metric_key = "nps", label = "NPS")

  } else if (metric_type == "proportions") {
    # Proportions - track ALL response codes
    if (!is.null(q_result$response_codes) && length(q_result$response_codes) > 0) {
      for (code in q_result$response_codes) {
        metrics[[length(metrics) + 1]] <- list(
          metric_key = paste0("proportion:", code),
          label = paste0("% ", code)
        )
      }
    }

  } else if (metric_type == "multi_mention") {
    # Multi-mention - track each column
    if (!is.null(q_result$tracked_columns)) {
      for (col_name in q_result$tracked_columns) {
        metrics[[length(metrics) + 1]] <- list(
          metric_key = paste0("mention:", col_name),
          label = paste0("% ", col_name)
        )
      }
    }

  } else if (metric_type == "category_mentions") {
    # Multi-mention category mode - track each category
    if (!is.null(q_result$response_categories)) {
      for (category in q_result$response_categories) {
        metrics[[length(metrics) + 1]] <- list(
          metric_key = paste0("mention:", category),
          label = paste0("% ", category)
        )
      }
    }
  }

  return(metrics)
}


#' Extract Metric Value from Wave Result
#'
#' Extracts the appropriate metric value from a wave result based on metric key.
#'
#' @keywords internal
extract_metric_value <- function(wave_result, metric_key, question_metric_type) {

  # Guard against NULL/empty metric_type
  if (is.null(question_metric_type) || length(question_metric_type) == 0 || !nzchar(question_metric_type)) {
    return(NA)
  }

  # Handle enhanced metrics (stored in metrics list)
  if (question_metric_type == "rating_enhanced" || question_metric_type == "composite_enhanced") {
    if (!is.null(wave_result$metrics) && !is.null(wave_result$metrics[[metric_key]])) {
      return(wave_result$metrics[[metric_key]])
    }
  }

  # Handle simple metrics
  if (metric_key == "mean") {
    return(wave_result$mean)
  } else if (metric_key == "nps") {
    return(wave_result$nps)
  } else if (startsWith(metric_key, "proportion:")) {
    # Extract proportion for specific response code
    code <- sub("proportion:", "", metric_key)
    if (!is.null(wave_result$proportions) && !is.null(wave_result$proportions[[code]])) {
      return(wave_result$proportions[[code]])
    }
  } else if (startsWith(metric_key, "mention:")) {
    # Extract mention proportion for specific column
    col_name <- sub("mention:", "", metric_key)
    if (!is.null(wave_result$mention_proportions) && !is.null(wave_result$mention_proportions[[col_name]])) {
      return(wave_result$mention_proportions[[col_name]])
    }
  }

  # Return NA if metric not found
  return(NA_real_)
}
