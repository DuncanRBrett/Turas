# ==============================================================================
# TurasTracker - Excel Output Writer (Core)
# ==============================================================================
#
# Generates Excel output for tracking analysis.
# Creates one sheet per question plus summary/metadata sheets.
#
# VERSION: 3.0.0 - Split into three files for maintainability
#
# Split files:
#   tracker_output.R          - Core orchestrator, summary, trend sheets, metadata
#   tracker_output_banners.R  - Banner breakout functions
#   tracker_output_extended.R - Extended formats, distribution, wave history
#
# Previously extracted modules:
#   lib/metric_types.R      - Metric type constants and validation
#   lib/output_formatting.R - Excel style creation
#
# SHARED UTILITIES: Uses /modules/shared/lib/ for common functions
#
# FEATURES:
# - Decimal separator properly respected via shared formatting
# - Report types: "detailed", "dashboard", "sig_matrix", "tracking_crosstab"
# - See tracker_dashboard_reports.R for dashboard implementations
# ==============================================================================

# Load shared utilities from consolidated location
# Note: formatting_utils.R should already be loaded by run_tracker.R via formatting_utils.R
# This is a safety check in case this file is sourced directly
if (!exists("find_turas_root", mode = "function")) {
  .output_script_dir <- tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) getwd())

  .shared_lib_path <- file.path(dirname(.output_script_dir), "shared", "lib")
  if (!dir.exists(.shared_lib_path)) {
    .shared_lib_path <- file.path(getwd(), "modules", "shared", "lib")
  }

  source(file.path(.shared_lib_path, "validation_utils.R"), local = FALSE)
  source(file.path(.shared_lib_path, "config_utils.R"), local = FALSE)
  source(file.path(.shared_lib_path, "formatting_utils.R"), local = FALSE)

  rm(.output_script_dir, .shared_lib_path)
}
# NOTE: Required modules are loaded by run_tracker.R in the correct order:
# - metric_types.R (metric type constants and validation)
# - output_formatting.R (Excel style definitions)
# ==============================================================================

#' Write Tracker Output to Excel
#'
#' Creates Excel workbook with trend analysis results.
#'
#' @param trend_results List. Trend results from calculate_all_trends() or calculate_trends_with_banners()
#' @param config Configuration object
#' @param wave_data List of wave data frames
#' @param output_path Character. Path for output file
#' @param banner_segments List. Banner segment definitions (optional, for Phase 3)
#' @return Character. Path to created file
#'
#' @export
write_tracker_output <- function(trend_results, config, wave_data, output_path = NULL, banner_segments = NULL, run_result = NULL) {

  # --- Input validation ---
  if (!is.list(trend_results) || length(trend_results) == 0) {
    tracker_refuse(
      code = "DATA_TREND_RESULTS_INVALID",
      title = "Invalid Trend Results for Excel Output",
      problem = "trend_results must be a non-empty list of trend results.",
      why_it_matters = "Without valid trend results, there is no data to write to the Excel report.",
      how_to_fix = "Ensure calculate_all_trends() or calculate_trends_with_banners() completed successfully before calling write_tracker_output()."
    )
  }
  if (!is.list(config) || is.null(config$waves)) {
    tracker_refuse(
      code = "CFG_CONFIG_INVALID",
      title = "Invalid Config for Excel Output",
      problem = "config must be a list containing a $waves data frame.",
      why_it_matters = "The config object drives wave ordering, labels, and output path resolution.",
      how_to_fix = "Pass the config object returned by load_tracking_config() to write_tracker_output()."
    )
  }

  cat("\n================================================================================\n")
  cat("WRITING EXCEL OUTPUT\n")
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
        cat("[WARNING]", paste0("Could not create output directory: ", output_dir, ". Using config directory."), "\n")
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
      filename <- paste0(project_name, "_Tracker_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    }

    # Combine directory and filename
    output_path <- file.path(output_dir, filename)
  }

  cat(paste0("Output file: ", output_path, "\n"))

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Create styles
  styles <- create_tracker_styles()

  # Write sheets
  write_summary_sheet(wb, config, wave_data, trend_results, styles, banner_segments)

  if (has_banners) {
    write_trend_sheets_with_banners(wb, trend_results, config, styles)
    write_change_summary_sheet(wb, trend_results, config, styles)
  } else {
    write_trend_sheets(wb, trend_results, config, styles)
  }

  write_metadata_sheet(wb, config, wave_data, styles)

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

  cat(paste0("\u2713 Output written to: ", output_path, "\n"))
  cat("================================================================================\n\n")

  return(output_path)
}


#' Write Summary Sheet
#'
#' Creates summary sheet with project info and wave overview.
#'
#' @keywords internal
write_summary_sheet <- function(wb, config, wave_data, trend_results, styles, banner_segments = NULL) {

  message("  Writing Summary sheet...")

  openxlsx::addWorksheet(wb, "Summary")

  current_row <- 1

  # Title
  project_name <- get_setting(config, "project_name", default = "Tracking Analysis")
  openxlsx::writeData(wb, "Summary", "TRACKING ANALYSIS SUMMARY",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, "Summary", styles$title, rows = current_row, cols = 1)
  current_row <- current_row + 1

  openxlsx::writeData(wb, "Summary", project_name,
                      startRow = current_row, startCol = 1, colNames = FALSE)
  current_row <- current_row + 2

  # Wave information
  openxlsx::writeData(wb, "Summary", "Wave Information:",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, "Summary", styles$header, rows = current_row, cols = 1)
  current_row <- current_row + 1

  # Wave table headers
  wave_headers <- c("Wave ID", "Wave Name", "Fieldwork Start", "Fieldwork End", "Sample Size")
  openxlsx::writeData(wb, "Summary", t(wave_headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, "Summary", styles$wave_header,
                    rows = current_row, cols = seq_along(wave_headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Wave data rows
  for (i in seq_len(nrow(config$waves))) {
    wave_id <- config$waves$WaveID[i]
    wave_df <- wave_data[[wave_id]]

    row_data <- c(
      wave_id,
      config$waves$WaveName[i],
      as.character(config$waves$FieldworkStart[i]),
      as.character(config$waves$FieldworkEnd[i]),
      nrow(wave_df)
    )

    openxlsx::writeData(wb, "Summary", t(row_data),
                        startRow = current_row, startCol = 1, colNames = FALSE)
    current_row <- current_row + 1
  }

  current_row <- current_row + 1

  # Questions tracked
  openxlsx::writeData(wb, "Summary", paste0("Questions Tracked: ", length(trend_results)),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  current_row <- current_row + 1

  # Generation timestamp
  openxlsx::writeData(wb, "Summary",
                      paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
                      startRow = current_row, startCol = 1, colNames = FALSE)

  # Set column widths
  openxlsx::setColWidths(wb, "Summary", cols = 1:5, widths = c(15, 25, 18, 18, 15))
}


#' Write Trend Sheets
#'
#' Creates one sheet per question with trend data.
#'
#' @keywords internal
write_trend_sheets <- function(wb, trend_results, config, styles) {

  message(paste0("  Writing ", length(trend_results), " trend sheets..."))

  wave_ids <- config$waves$WaveID
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  for (q_code in names(trend_results)) {
    result <- trend_results[[q_code]]

    # Create safe sheet name (max 31 chars, no special chars)
    sheet_name <- substr(q_code, 1, 31)
    sheet_name <- gsub("[\\[\\]\\*/\\\\?:]", "_", sheet_name)

    openxlsx::addWorksheet(wb, sheet_name)

    current_row <- 1

    # Question header
    openxlsx::writeData(wb, sheet_name, result$question_code,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$title, rows = current_row, cols = 1)
    current_row <- current_row + 1

    openxlsx::writeData(wb, sheet_name, result$question_text,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    current_row <- current_row + 2

    # Validate metric type
    validate_metric_type(result$metric_type, context = "write_trend_sheets")

    # Write trend table based on metric type
    if (result$metric_type == METRIC_TYPES$MEAN) {
      current_row <- write_mean_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == METRIC_TYPES$NPS) {
      current_row <- write_nps_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == METRIC_TYPES$PROPORTIONS) {
      current_row <- write_proportions_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == METRIC_TYPES$RATING_ENHANCED) {
      current_row <- write_enhanced_rating_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == METRIC_TYPES$COMPOSITE_ENHANCED) {
      current_row <- write_enhanced_composite_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == METRIC_TYPES$MULTI_MENTION) {
      current_row <- write_multi_mention_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)
    }
  }
}


#' Write Mean Trend Table
#'
#' @keywords internal
write_mean_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Headers
  headers <- c("Metric", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = seq_along(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Mean row - write label and numbers separately to preserve numeric type
  # First, write the label
  openxlsx::writeData(wb, sheet_name, "Mean",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  # Then write numeric values (rounded to specified decimal places)
  mean_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- safe_wave_result(result$wave_results, wave_ids[i])
    if (isTRUE(wave_result$available)) {
      mean_values[i] <- round(wave_result$mean, decimal_places)
    } else {
      mean_values[i] <- NA
    }
  }

  openxlsx::writeData(wb, sheet_name, t(mean_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)

  # Apply number format to numeric columns
  number_style <- openxlsx::createStyle(numFmt = number_format)
  openxlsx::addStyle(wb, sheet_name, number_style,
                    rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)
  current_row <- current_row + 1

  # Sample size row - write label and numbers separately
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  # Write numeric values
  n_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- safe_wave_result(result$wave_results, wave_ids[i])
    if (isTRUE(wave_result$available)) {
      n_values[i] <- wave_result$n_unweighted
    } else {
      n_values[i] <- NA
    }
  }

  openxlsx::writeData(wb, sheet_name, t(n_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                    rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE)
  current_row <- current_row + 2

  # Distribution section (show % for each rating value)
  current_row <- write_distribution_table(wb, sheet_name, result, wave_ids, config, styles, current_row)
  current_row <- current_row + 1

  # Changes section
  if (length(result$changes) > 0) {
    openxlsx::writeData(wb, sheet_name, "Wave-over-Wave Changes:",
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$header, rows = current_row, cols = 1)
    current_row <- current_row + 1

    change_headers <- c("Comparison", "Absolute Change", "% Change", "Significant")
    openxlsx::writeData(wb, sheet_name, t(change_headers),
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$wave_header,
                      rows = current_row, cols = seq_along(change_headers), gridExpand = TRUE)
    current_row <- current_row + 1

    for (change_name in names(result$changes)) {
      change <- result$changes[[change_name]]

      comparison_label <- paste0(change$from_wave, " → ", change$to_wave)

      # Get significance
      sig_key <- paste0(change$from_wave, "_vs_", change$to_wave)
      sig_test <- result$significance[[sig_key]]
      is_sig <- is_significant(sig_test)

      # Write label
      openxlsx::writeData(wb, sheet_name, comparison_label,
                          startRow = current_row, startCol = 1, colNames = FALSE)

      # Write numeric values separately to preserve type (rounded)
      openxlsx::writeData(wb, sheet_name, round(change$absolute_change, decimal_places),
                          startRow = current_row, startCol = 2, colNames = FALSE)
      openxlsx::writeData(wb, sheet_name, round(change$percentage_change, decimal_places),
                          startRow = current_row, startCol = 3, colNames = FALSE)
      openxlsx::writeData(wb, sheet_name, if (is_sig) "Yes" else "No",
                          startRow = current_row, startCol = 4, colNames = FALSE)

      # Style based on direction
      change_style <- if (!is.na(change$absolute_change) && change$absolute_change > 0) {
        styles$change_positive
      } else if (!is.na(change$absolute_change) && change$absolute_change < 0) {
        styles$change_negative
      } else {
        styles$data_number
      }

      # Apply number format with decimal separator to numeric columns
      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, change_style, rows = current_row, cols = 2:3, gridExpand = TRUE)
      openxlsx::addStyle(wb, sheet_name, number_style, rows = current_row, cols = 2:3, gridExpand = TRUE, stack = TRUE)

      if (is_sig) {
        openxlsx::addStyle(wb, sheet_name, styles$significant, rows = current_row, cols = 4)
      }

      current_row <- current_row + 1
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1:10, widths = "auto")

  return(current_row + 1)
}


#' Write NPS Trend Table
#'
#' @keywords internal
write_nps_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Metric", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = seq_along(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # NPS row
  metrics <- c("NPS Score", "% Promoters (9-10)", "% Passives (7-8)", "% Detractors (0-6)", "Sample Size (n)")

  for (metric in metrics) {
    # Write label
    openxlsx::writeData(wb, sheet_name, metric,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values
    metric_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- safe_wave_result(result$wave_results, wave_ids[i])

      if (isTRUE(wave_result$available)) {
        val <- if (metric == "NPS Score") {
          wave_result$nps
        } else if (metric == "% Promoters (9-10)") {
          wave_result$promoters_pct
        } else if (metric == "% Passives (7-8)") {
          wave_result$passives_pct
        } else if (metric == "% Detractors (0-6)") {
          wave_result$detractors_pct
        } else {
          wave_result$n_unweighted  # Sample size - don't round
        }
        # Round all values except sample size
        metric_values[i] <- if (metric == "Sample Size (n)") val else round(val, decimal_places)
      } else {
        metric_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(metric_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply appropriate number format
    if (metric == "Sample Size (n)") {
      openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                        rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE)
    } else {
      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)
    }
    current_row <- current_row + 1
  }

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1:10, widths = "auto")

  return(current_row + 1)
}


#' Write Proportions Trend Table
#'
#' @keywords internal
write_proportions_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Response Option", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = seq_along(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Row for each response code
  for (code in result$response_codes) {
    # Write label
    openxlsx::writeData(wb, sheet_name, as.character(code),
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values (rounded)
    code_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- safe_wave_result(result$wave_results, wave_ids[i])

      if (isTRUE(wave_result$available)) {
        pct <- wave_result$proportions[[as.character(code)]]
        code_values[i] <- round(pct, decimal_places)
      } else {
        code_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(code_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)
    current_row <- current_row + 1
  }

  current_row <- current_row + 1

  # Sample size row - write label and numbers separately
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  # Write numeric values
  n_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- safe_wave_result(result$wave_results, wave_ids[i])
    if (isTRUE(wave_result$available)) {
      n_values[i] <- wave_result$n_unweighted
    } else {
      n_values[i] <- NA
    }
  }

  openxlsx::writeData(wb, sheet_name, t(n_values),
                      startRow = current_row, startCol = 2, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$data_integer,
                    rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE)

  # Set column widths
  openxlsx::setColWidths(wb, sheet_name, cols = 1:10, widths = "auto")

  return(current_row + 1)
}


#' Write Metadata Sheet
#'
#' @keywords internal
write_metadata_sheet <- function(wb, config, wave_data, styles) {

  message("  Writing Metadata sheet...")

  openxlsx::addWorksheet(wb, "Metadata")

  current_row <- 1

  # Title
  openxlsx::writeData(wb, "Metadata", "Configuration Metadata",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, "Metadata", styles$title, rows = current_row, cols = 1)
  current_row <- current_row + 2

  # Settings
  openxlsx::writeData(wb, "Metadata", "Analysis Settings:",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, "Metadata", styles$header, rows = current_row, cols = 1)
  current_row <- current_row + 1

  # Write key settings
  key_settings <- c("project_name", "alpha", "minimum_base", "decimal_places_ratings", "show_significance")

  for (setting in key_settings) {
    val <- get_setting(config, setting, default = "Not set")
    openxlsx::writeData(wb, "Metadata", setting, startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::writeData(wb, "Metadata", as.character(val), startRow = current_row, startCol = 2)
    current_row <- current_row + 1
  }

  current_row <- current_row + 1

  # Data files
  openxlsx::writeData(wb, "Metadata", "Data Files:",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, "Metadata", styles$header, rows = current_row, cols = 1)
  current_row <- current_row + 1

  for (i in seq_len(nrow(config$waves))) {
    wave_id <- config$waves$WaveID[i]
    data_file <- config$waves$DataFile[i]
    openxlsx::writeData(wb, "Metadata", wave_id, startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::writeData(wb, "Metadata", data_file, startRow = current_row, startCol = 2)
    current_row <- current_row + 1
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Metadata", cols = 1:2, widths = c(25, 50))
}
