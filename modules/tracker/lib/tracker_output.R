# ==============================================================================
# TurasTracker - Excel Output Writer (Main Orchestration)
# ==============================================================================
#
# Main orchestration file for Excel output generation. Coordinates workbook
# creation and dispatches to specialized output modules.
#
# VERSION: 3.0.0 - Refactored for maintainability (December 2025)
#
# REFACTORING COMPLETE:
# This file has been split into focused modules:
#
#   tracker_output.R (this file - orchestration, ~350 lines)
#     - write_tracker_output()
#     - create_tracker_styles()
#     - write_summary_sheet()
#     - write_metadata_sheet()
#     - write_trend_sheets()
#
#   tracker_output_tables.R (trend table writers)
#     - write_mean_trend_table()
#     - write_nps_trend_table()
#     - write_proportions_trend_table()
#     - write_distribution_table()
#     - write_enhanced_rating_trend_table()
#     - write_enhanced_composite_trend_table()
#     - write_multi_mention_trend_table()
#
#   tracker_output_banners.R (banner/segment output)
#     - detect_banner_results()
#     - write_trend_sheets_with_banners()
#     - write_banner_trend_table()
#     - write_change_summary_sheet()
#
#   tracker_output_history.R (wave history output)
#     - write_wave_history_output()
#     - write_wave_history_sheet()
#     - extract_wave_history_metrics()
#     - extract_metric_value()
#
# SHARED UTILITIES: Uses /modules/shared/lib/ for common functions
#
# FEATURES:
# - Decimal separator properly respected via shared formatting
# - Report types: "detailed", "dashboard", "sig_matrix"
# - See tracker_dashboard_reports.R for dashboard implementations
# ==============================================================================

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Load shared utilities from consolidated location
# Note: formatting_utils.R should already be loaded by run_tracker.R
if (!exists("find_turas_root", mode = "function")) {
  # Find the shared/lib path - try multiple locations
  .shared_lib_path <- NULL
  .shared_lib_candidates <- c(
    # If script_dir is set (from parent run_tracker.R), go up to modules/shared/lib
    if (exists("script_dir") && !is.null(script_dir) && length(script_dir) > 0 && nzchar(script_dir[1])) {
      file.path(dirname(script_dir[1]), "shared", "lib")  # ../shared/lib from tracker dir
    } else NULL,
    # Try relative to current working directory
    file.path(getwd(), "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    # Try TURAS_HOME if set
    file.path(Sys.getenv("TURAS_HOME", unset = ""), "modules", "shared", "lib")
  )
  .shared_lib_candidates <- .shared_lib_candidates[!is.null(.shared_lib_candidates) & nzchar(.shared_lib_candidates)]

  for (.candidate in .shared_lib_candidates) {
    if (dir.exists(.candidate)) {
      .shared_lib_path <- .candidate
      break
    }
  }

  if (!is.null(.shared_lib_path)) {
    if (file.exists(file.path(.shared_lib_path, "validation_utils.R"))) {
      source(file.path(.shared_lib_path, "validation_utils.R"), local = FALSE)
    }
    if (file.exists(file.path(.shared_lib_path, "config_utils.R"))) {
      source(file.path(.shared_lib_path, "config_utils.R"), local = FALSE)
    }
    if (file.exists(file.path(.shared_lib_path, "formatting_utils.R"))) {
      source(file.path(.shared_lib_path, "formatting_utils.R"), local = FALSE)
    }
  }

  rm(list = c(".shared_lib_path", ".shared_lib_candidates", ".candidate")[
    c(".shared_lib_path", ".shared_lib_candidates", ".candidate") %in% ls(all.names = TRUE)
  ])
}

# Get the directory of this file for sourcing helper modules
.output_lib_dir <- if (exists("TRACKER_LIB_DIR")) {
  TRACKER_LIB_DIR
} else if (exists("script_dir") && !is.null(script_dir) && length(script_dir) > 0 && nzchar(script_dir[1])) {
  file.path(script_dir[1], "lib")
} else {
  tryCatch({
    ofile <- sys.frame(1)$ofile
    if (!is.null(ofile) && length(ofile) > 0 && nzchar(ofile)) {
      dirname(ofile)
    } else {
      getwd()
    }
  }, error = function(e) getwd())
}

# Source the refactored output modules with checks
.to_safe_source <- function(fname) {
  fpath <- file.path(.output_lib_dir, fname)
  if (!file.exists(fpath)) {
    stop(paste0("Cannot find: ", fpath, "\n  .output_lib_dir=", .output_lib_dir))
  }
  source(fpath)
}
.to_safe_source("tracker_output_tables.R")
.to_safe_source("tracker_output_banners.R")
.to_safe_source("tracker_output_history.R")
rm(.to_safe_source)


# ==============================================================================
# MAIN OUTPUT FUNCTION
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
#' @param run_result List. TRS run result for status sheet
#' @return Character. Path to created file
#'
#' @export
write_tracker_output <- function(trend_results, config, wave_data, output_path = NULL, banner_segments = NULL, run_result = NULL) {

  cat("\n================================================================================\n")
  cat("WRITING EXCEL OUTPUT\n")
  cat("================================================================================\n\n")

  # Debug: Check inputs
  cat("[DEBUG] trend_results type:", class(trend_results)[1], "length:", length(trend_results), "\n")
  cat("[DEBUG] config type:", class(config)[1], "\n")
  cat("[DEBUG] wave_data type:", class(wave_data)[1], "length:", length(wave_data), "\n")
  cat("[DEBUG] output_path:", if (is.null(output_path)) "NULL" else output_path, "\n")

  # Detect if results have banner breakouts
  cat("[DEBUG] Calling detect_banner_results...\n")
  has_banners <- detect_banner_results(trend_results)
  cat("[DEBUG] has_banners:", has_banners, "\n")

  if (has_banners) {
    cat("  Detected banner breakout results\n")
  }

  # Determine output path
  cat("[DEBUG] Calling resolve_output_path...\n")
  output_path <- resolve_output_path(output_path, config)
  cat("[DEBUG] resolved output_path:", output_path, "\n")

  cat(paste0("Output file: ", output_path, "\n"))

  # Create workbook
  cat("[DEBUG] Creating workbook...\n")
  wb <- openxlsx::createWorkbook()
  cat("[DEBUG] Workbook created OK\n")

  # Create styles
  cat("[DEBUG] Creating styles...\n")
  styles <- create_tracker_styles()
  cat("[DEBUG] Styles created OK\n")

  # Write sheets
  cat("[DEBUG] Writing summary sheet...\n")
  write_summary_sheet(wb, config, wave_data, trend_results, styles, banner_segments)
  cat("[DEBUG] Summary sheet written OK\n")

  if (has_banners) {
    cat("[DEBUG] Writing trend sheets with banners...\n")
    write_trend_sheets_with_banners(wb, trend_results, config, styles)
    cat("[DEBUG] Writing change summary sheet...\n")
    write_change_summary_sheet(wb, trend_results, config, styles)
    cat("[DEBUG] Banner sheets written OK\n")
  } else {
    cat("[DEBUG] Writing trend sheets...\n")
    write_trend_sheets(wb, trend_results, config, styles)
    cat("[DEBUG] Trend sheets written OK\n")
  }

  cat("[DEBUG] Writing metadata sheet...\n")
  write_metadata_sheet(wb, config, wave_data, styles)
  cat("[DEBUG] Metadata sheet written OK\n")

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


#' Resolve Output Path
#'
#' Determines the output file path from settings or generates a default.
#'
#' @keywords internal
resolve_output_path <- function(output_path, config) {

  if (!is.null(output_path)) {
    return(output_path)
  }

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
    filename <- paste0(project_name, "_Tracker_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
  }

  # Combine directory and filename
  return(file.path(output_dir, filename))
}


# ==============================================================================
# STYLE CREATION
# ==============================================================================

#' Create Tracker Styles
#'
#' Creates style objects for Excel formatting.
#'
#' @return List of openxlsx style objects
#' @keywords internal
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
# SHEET WRITERS
# ==============================================================================

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
                    rows = current_row, cols = 1:length(wave_headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Wave data rows
  for (i in 1:nrow(config$waves)) {
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
  cat("[DEBUG] wave_ids:", paste(wave_ids, collapse=", "), "length:", length(wave_ids), "\n")

  for (q_code in names(trend_results)) {
    cat("[DEBUG] Processing question:", q_code, "\n")
    result <- trend_results[[q_code]]
    cat("[DEBUG]   metric_type:", result$metric_type, "\n")

    # Create safe sheet name (max 31 chars, no special chars)
    sheet_name <- substr(q_code, 1, 31)
    sheet_name <- gsub("[\\[\\]\\*/\\\\?:]", "_", sheet_name)
    cat("[DEBUG]   sheet_name:", sheet_name, "\n")

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

    # Write trend table based on metric type
    cat("[DEBUG]   Calling write function for metric_type:", result$metric_type, "\n")
    if (result$metric_type == "mean") {
      current_row <- write_mean_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == "nps") {
      current_row <- write_nps_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == "proportions") {
      current_row <- write_proportions_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == "rating_enhanced") {
      current_row <- write_enhanced_rating_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == "composite_enhanced") {
      current_row <- write_enhanced_composite_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)

    } else if (result$metric_type == "multi_mention") {
      current_row <- write_multi_mention_trend_table(wb, sheet_name, result, wave_ids, config, styles, current_row)
    }
    cat("[DEBUG]   Done with question:", q_code, "\n")
  }
  cat("[DEBUG] All trend sheets written\n")
}


#' Write Metadata Sheet
#'
#' Creates metadata sheet with configuration details.
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

  for (i in 1:nrow(config$waves)) {
    wave_id <- config$waves$WaveID[i]
    data_file <- config$waves$DataFile[i]
    openxlsx::writeData(wb, "Metadata", wave_id, startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::writeData(wb, "Metadata", data_file, startRow = current_row, startCol = 2)
    current_row <- current_row + 1
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Metadata", cols = 1:2, widths = c(25, 50))
}
