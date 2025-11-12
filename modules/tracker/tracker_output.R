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
    project_name <- get_setting(config, "project_name", default = "Tracking")
    project_name <- gsub("[^A-Za-z0-9_-]", "_", project_name)  # Sanitize
    output_path <- paste0(project_name, "_Tracker_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
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
      # Changes header
      openxlsx::writeData(wb, sheet_name, "Wave-over-Wave Changes (Total):",
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

      # Write change rows
      for (change_name in names(total_result$changes)) {
        change <- total_result$changes[[change_name]]

        comparison_label <- paste0(change$from_wave, " → ", change$to_wave)

        # Get significance
        sig_key <- paste0(change$from_wave, "_vs_", change$to_wave)
        sig_test <- total_result$significance[[sig_key]]
        is_sig <- !is.null(sig_test) && sig_test$significant

        # Write label
        openxlsx::writeData(wb, sheet_name, comparison_label,
                            startRow = current_row, startCol = 1, colNames = FALSE)

        # Write numeric values separately (rounded)
        openxlsx::writeData(wb, sheet_name, round(change$from_value, decimal_places),
                            startRow = current_row, startCol = 2, colNames = FALSE)
        openxlsx::writeData(wb, sheet_name, round(change$to_value, decimal_places),
                            startRow = current_row, startCol = 3, colNames = FALSE)
        openxlsx::writeData(wb, sheet_name, round(change$absolute_change, decimal_places),
                            startRow = current_row, startCol = 4, colNames = FALSE)
        openxlsx::writeData(wb, sheet_name, round(change$percentage_change, decimal_places),
                            startRow = current_row, startCol = 5, colNames = FALSE)
        openxlsx::writeData(wb, sheet_name, if (is_sig) "Yes" else "No",
                            startRow = current_row, startCol = 6, colNames = FALSE)

        # Apply number format
        number_style <- openxlsx::createStyle(numFmt = number_format)
        openxlsx::addStyle(wb, sheet_name, number_style,
                          rows = current_row, cols = 2:5, gridExpand = TRUE, stack = TRUE)

        # Style based on significance
        if (is_sig) {
          openxlsx::addStyle(wb, sheet_name, styles$significant,
                            rows = current_row, cols = 4:5, gridExpand = TRUE, stack = TRUE)
        }

        current_row <- current_row + 1
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
