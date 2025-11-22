# ==============================================================================
# TurasTracker - Excel Output Writer
# ==============================================================================
#
# Generates Excel output for tracking analysis.
# Creates one sheet per question plus summary/metadata sheets.
#
# VERSION: 2.0.0 - Phase 2 Update
# CHANGES: Now uses shared/formatting.R for consistent decimal separator handling
#
# PHASE 2 UPDATE:
# - Decimal separator now properly respected (was hardcoded to "." before)
# - Uses create_excel_number_format() from shared/formatting.R
# - Fixes inconsistency with TurasTabs decimal separator behavior
#
# ==============================================================================

# Load shared formatting module (Phase 2 refactoring)
# Robust path resolution - searches up directory tree to find Turas root
find_turas_root <- function() {
  # Method 1: Check if TURAS_ROOT is already set
  if (exists("TURAS_ROOT", envir = .GlobalEnv)) {
    return(get("TURAS_ROOT", envir = .GlobalEnv))
  }
  
  # Method 2: Start from current working directory
  current_dir <- getwd()
  
  # Search up directory tree for Turas root markers
  while (current_dir != dirname(current_dir)) {  # Stop at filesystem root
    # Check for Turas root markers
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        (dir.exists(file.path(current_dir, "shared")) && 
         dir.exists(file.path(current_dir, "modules")))) {
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }
  
  # Method 3: Try relative paths from module location
  for (rel_path in c("../..", "../../..", "../../../..")) {
    test_path <- normalizePath(file.path(rel_path, "shared", "formatting.R"), mustWork = FALSE)
    if (file.exists(test_path)) {
      return(normalizePath(dirname(dirname(test_path)), mustWork = TRUE))
    }
  }
  
  stop(paste0(
    "Cannot locate Turas root directory.\n",
    "Please ensure you're running from the Turas directory.\n",
    "Current working directory: ", getwd()
  ))
}

turas_root <- find_turas_root()
source(file.path(turas_root, "shared", "formatting.R"), local = FALSE)

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
write_tracker_output <- function(trend_results, config, wave_data, output_path = NULL, banner_segments = NULL) {

  message("\n================================================================================")
  message("WRITING EXCEL OUTPUT")
  message("================================================================================\n")

  # Detect if results have banner breakouts
  has_banners <- detect_banner_results(trend_results)

  if (has_banners) {
    message("  Detected banner breakout results")
  }

  # Determine output path
  if (is.null(output_path)) {
    # Get output directory from settings or use config file location
    output_dir <- get_setting(config, "output_dir", default = NULL)

    if (is.null(output_dir)) {
      # Default to same directory as config file
      output_dir <- dirname(config$config_path)
    }

    # Generate filename
    project_name <- get_setting(config, "project_name", default = "Tracking")
    project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)  # Sanitize
    filename <- paste0(project_name, "_Tracker_", format(Sys.Date(), "%Y%m%d"), ".xlsx")

    # Combine directory and filename
    output_path <- file.path(output_dir, filename)
  }

  message(paste0("Output file: ", output_path))

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

  # Save workbook
  message(paste0("\nSaving workbook..."))
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  message(paste0("✓ Output written to: ", output_path))
  message("================================================================================\n")

  return(output_path)
}


#' Create Tracker Styles
#'
#' SHARED CODE NOTE: Should use /shared/excel_styles.R::create_standard_styles()
#'
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

    # Write trend table based on metric type
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
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
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
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
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
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
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
                      rows = current_row, cols = 1:length(change_headers), gridExpand = TRUE)
    current_row <- current_row + 1

    for (change_name in names(result$changes)) {
      change <- result$changes[[change_name]]

      comparison_label <- paste0(change$from_wave, " → ", change$to_wave)

      # Get significance
      sig_key <- paste0(change$from_wave, "_vs_", change$to_wave)
      sig_test <- result$significance[[sig_key]]
      is_sig <- !is.null(sig_test) && sig_test$significant

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
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
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
      wave_result <- result$wave_results[[wave_ids[i]]]

      if (wave_result$available) {
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
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
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
      wave_result <- result$wave_results[[wave_ids[i]]]

      if (wave_result$available) {
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
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
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
              is_sig <- isTRUE(!is.null(sig_test) && !is.na(sig_test$significant) && sig_test$significant)

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
          # Use isTRUE() to safely handle NA/NULL cases
          is_sig <- isTRUE(!is.null(sig_test) && !is.na(sig_test$significant) && sig_test$significant)

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


#' Write Distribution Table
#'
#' Writes distribution of responses (% for each rating value) for rating questions.
#'
#' @keywords internal
write_distribution_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  # Only show distribution for rating/mean questions
  if (is.null(result$metric_type) || result$metric_type != "mean") {
    return(start_row)
  }

  current_row <- start_row

  # Header
  openxlsx::writeData(wb, sheet_name, "Response Distribution:",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header, rows = current_row, cols = 1)
  current_row <- current_row + 1

  # Calculate distribution for each wave
  # First, find all unique values across all waves
  all_values <- c()
  for (wave_id in wave_ids) {
    wave_result <- result$wave_results[[wave_id]]
    if (wave_result$available && !is.null(wave_result$values)) {
      all_values <- c(all_values, wave_result$values)
    }
  }

  if (length(all_values) == 0) {
    # No distribution data available
    return(current_row)
  }

  # Get unique values and sort
  unique_values <- sort(unique(all_values[!is.na(all_values)]))

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)

  # Phase 2 Update: Use shared formatting module
  # This FIXES the issue where decimal_separator was ignored!
  # Now properly respects config setting instead of always using "."
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Write distribution table
  headers <- c("Rating Value", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$wave_header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write row for each rating value
  for (val in unique_values) {
    # Write label
    openxlsx::writeData(wb, sheet_name, as.character(val),
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values
    dist_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]

      if (wave_result$available && !is.null(wave_result$values)) {
        # Calculate percentage for this value
        values <- wave_result$values
        weights <- if (!is.null(wave_result$weights)) wave_result$weights else rep(1, length(values))

        # Count weighted responses for this value
        matching <- !is.na(values) & values == val
        weighted_count <- sum(weights[matching])
        total_weighted <- sum(weights[!is.na(values)])

        if (total_weighted > 0) {
          pct <- (weighted_count / total_weighted) * 100
          dist_values[i] <- round(pct, decimal_places)
        } else {
          dist_values[i] <- NA
        }
      } else {
        dist_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(dist_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)
    current_row <- current_row + 1
  }

  return(current_row)
}


# ==============================================================================
# ENHANCED OUTPUT FORMATTING (Enhancement Phases 1 & 2)
# ==============================================================================

#' Write Enhanced Rating Trend Table
#'
#' Writes table for rating questions with multiple metrics (mean, top_box, etc.)
#'
#' @keywords internal
write_enhanced_rating_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places from config
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Metric", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write row for each metric in tracking_specs
  for (metric_name in result$tracking_specs) {
    metric_lower <- tolower(trimws(metric_name))

    # Skip distribution (handled separately below)
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
    metric_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]
      if (wave_result$available && !is.null(wave_result$metrics)) {
        metric_val <- wave_result$metrics[[metric_lower]]
        if (!is.null(metric_val)) {
          metric_values[i] <- round(metric_val, decimal_places)
        } else {
          metric_values[i] <- NA
        }
      } else {
        metric_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(metric_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)

    current_row <- current_row + 1
  }

  # Sample size row
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  n_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
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

  return(current_row)
}


#' Write Enhanced Composite Trend Table
#'
#' Same as enhanced rating (composites support same metrics)
#'
#' @keywords internal
write_enhanced_composite_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {
  return(write_enhanced_rating_trend_table(wb, sheet_name, result, wave_ids, config, styles, start_row))
}


#' Write Multi-Mention Trend Table
#'
#' Writes table for multi-mention questions showing % mentioning each option
#'
#' @keywords internal
write_multi_mention_trend_table <- function(wb, sheet_name, result, wave_ids, config, styles, start_row) {

  current_row <- start_row

  # Get decimal separator and decimal places
  decimal_sep <- get_setting(config, "decimal_separator", default = ".")
  decimal_places <- get_setting(config, "decimal_places_ratings", default = 1)
  number_format <- create_excel_number_format(decimal_places, decimal_sep)

  # Headers
  headers <- c("Option", wave_ids)
  openxlsx::writeData(wb, sheet_name, t(headers),
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$header,
                    rows = current_row, cols = 1:length(headers), gridExpand = TRUE)
  current_row <- current_row + 1

  # Write row for each tracked column
  for (col_name in result$tracked_columns) {
    # Write label
    openxlsx::writeData(wb, sheet_name, col_name,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

    # Collect numeric values (% mentioning)
    mention_values <- numeric(length(wave_ids))
    for (i in seq_along(wave_ids)) {
      wave_result <- result$wave_results[[wave_ids[i]]]
      if (wave_result$available && !is.null(wave_result$mention_proportions)) {
        mention_pct <- wave_result$mention_proportions[[col_name]]
        if (!is.null(mention_pct) && !is.na(mention_pct)) {
          mention_values[i] <- round(mention_pct, decimal_places)
        } else {
          mention_values[i] <- NA
        }
      } else {
        mention_values[i] <- NA
      }
    }

    # Write numeric values
    openxlsx::writeData(wb, sheet_name, t(mention_values),
                        startRow = current_row, startCol = 2, colNames = FALSE)

    # Apply number format
    number_style <- openxlsx::createStyle(numFmt = number_format)
    openxlsx::addStyle(wb, sheet_name, number_style,
                      rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)

    current_row <- current_row + 1
  }

  # Add additional metrics if present
  # Check first wave for additional metrics
  first_wave_result <- result$wave_results[[wave_ids[1]]]
  if (first_wave_result$available && !is.null(first_wave_result$additional_metrics)) {
    additional_metrics <- first_wave_result$additional_metrics

    if (!is.null(additional_metrics$any_mention_pct)) {
      current_row <- current_row + 1  # Blank row

      # "Any mention" row
      openxlsx::writeData(wb, sheet_name, "% Mentioning Any",
                          startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

      any_values <- numeric(length(wave_ids))
      for (i in seq_along(wave_ids)) {
        wave_result <- result$wave_results[[wave_ids[i]]]
        if (wave_result$available && !is.null(wave_result$additional_metrics$any_mention_pct)) {
          any_values[i] <- round(wave_result$additional_metrics$any_mention_pct, decimal_places)
        } else {
          any_values[i] <- NA
        }
      }

      openxlsx::writeData(wb, sheet_name, t(any_values),
                          startRow = current_row, startCol = 2, colNames = FALSE)

      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)

      current_row <- current_row + 1
    }

    if (!is.null(additional_metrics$count_mean)) {
      # "Mean count" row
      openxlsx::writeData(wb, sheet_name, "Mean # of Mentions",
                          startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

      count_values <- numeric(length(wave_ids))
      for (i in seq_along(wave_ids)) {
        wave_result <- result$wave_results[[wave_ids[i]]]
        if (wave_result$available && !is.null(wave_result$additional_metrics$count_mean)) {
          count_values[i] <- round(wave_result$additional_metrics$count_mean, decimal_places)
        } else {
          count_values[i] <- NA
        }
      }

      openxlsx::writeData(wb, sheet_name, t(count_values),
                          startRow = current_row, startCol = 2, colNames = FALSE)

      number_style <- openxlsx::createStyle(numFmt = number_format)
      openxlsx::addStyle(wb, sheet_name, number_style,
                        rows = current_row, cols = 2:(length(wave_ids) + 1), gridExpand = TRUE, stack = TRUE)

      current_row <- current_row + 1
    }
  }

  # Sample size row
  current_row <- current_row + 1
  openxlsx::writeData(wb, sheet_name, "Sample Size (n)",
                      startRow = current_row, startCol = 1, colNames = FALSE)
  openxlsx::addStyle(wb, sheet_name, styles$metric_label, rows = current_row, cols = 1)

  n_values <- numeric(length(wave_ids))
  for (i in seq_along(wave_ids)) {
    wave_result <- result$wave_results[[wave_ids[i]]]
    if (wave_result$available) {
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

  return(current_row)
}


# ==============================================================================
# WAVE HISTORY REPORT FORMAT
# ==============================================================================

#' Write Wave History Output to Excel
#'
#' Creates Wave History format Excel workbook with one row per question.
#' Format: QuestionCode | Question | Type | Wave 1 | Wave 2 | ... | Wave N
#'
#' @param trend_results List. Trend results from calculate_all_trends() or calculate_trends_with_banners()
#' @param config Configuration object
#' @param wave_data List of wave data frames
#' @param output_path Character. Path for output file
#' @param banner_segments List. Banner segment definitions (optional)
#' @return Character. Path to created file
#'
#' @export
write_wave_history_output <- function(trend_results, config, wave_data, output_path = NULL, banner_segments = NULL) {

  message("\n================================================================================")
  message("WRITING WAVE HISTORY EXCEL OUTPUT")
  message("================================================================================\n")

  # Detect if results have banner breakouts
  has_banners <- detect_banner_results(trend_results)

  if (has_banners) {
    message("  Detected banner breakout results")
  }

  # Determine output path
  if (is.null(output_path)) {
    # Get output directory from settings or use config file location
    output_dir <- get_setting(config, "output_dir", default = NULL)

    if (is.null(output_dir)) {
      # Default to same directory as config file
      output_dir <- dirname(config$config_path)
    }

    # Generate filename
    project_name <- get_setting(config, "project_name", default = "Tracking")
    project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)  # Sanitize
    filename <- paste0(project_name, "_WaveHistory_", format(Sys.Date(), "%Y%m%d"), ".xlsx")

    # Combine directory and filename
    output_path <- file.path(output_dir, filename)
  }

  message(paste0("Output file: ", output_path))

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

  # Save workbook
  message(paste0("\nSaving workbook..."))
  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  message(paste0("✓ Wave History output written to: ", output_path))
  message("================================================================================\n")

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

  metric_type <- q_result$metric_type

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
  }

  return(metrics)
}


#' Extract Metric Value from Wave Result
#'
#' Extracts the appropriate metric value from a wave result based on metric key.
#'
#' @keywords internal
extract_metric_value <- function(wave_result, metric_key, question_metric_type) {

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
