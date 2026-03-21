# ==============================================================================
# TURAS STATS PACK WRITER
# ==============================================================================
#
# Generates a standalone diagnostic Excel workbook ("stats pack") for advanced
# partners and research statisticians. Provides a full, transparent record of:
#   - What data was received and what was analysed
#   - All analytical assumptions and parameters
#   - Warnings and data quality flags
#   - Reproducibility information (versions, seeds, packages)
#   - Full config echo
#
# USAGE:
#   payload <- list(
#     module          = "CONFIDENCE",
#     project_name    = "Brand Tracker Q1",   # optional
#     analyst_name    = "Jane Smith",          # optional
#     research_house  = "Acme Research",       # optional
#     run_timestamp   = Sys.time(),
#     turas_version   = "10.1",
#     status          = "PASS",
#     duration_seconds = 12.3,
#     data_receipt    = list(file_name, n_rows, n_cols, questions_in_config),
#     data_used       = list(n_respondents, n_excluded, questions_analysed,
#                            questions_skipped, per_item_stats, exclusions_detail),
#     assumptions     = list("Confidence Level" = "95%", ...),  # named list
#     run_result      = run_result,   # TRS run result (for warnings)
#     packages        = c("openxlsx", "readxl"),  # packages to report
#     config_echo     = config        # full config list
#   )
#
#   output_path <- sub("\\.xlsx$", "_stats_pack.xlsx", main_output_path)
#   turas_write_stats_pack(payload, output_path)
#
# Version: 1.0
# Date: 2026-03
#
# ==============================================================================


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Write Turas Stats Pack to Excel
#'
#' Generates a complete diagnostic workbook documenting data received,
#' data used, assumptions, warnings, and reproducibility information.
#'
#' @param payload List. Diagnostic payload (see file header for structure)
#' @param output_path Character. Path for the stats pack .xlsx file
#' @param protect_sheets Logical. Lock sheets as read-only (default TRUE)
#'
#' @return Character. Output path (invisibly) or NULL on failure
#' @export
turas_write_stats_pack <- function(payload, output_path, protect_sheets = TRUE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    message("[TRS WARNING] STATS_PACK: openxlsx not available - stats pack not written")
    return(invisible(NULL))
  }

  if (!is.list(payload)) {
    message("[TRS WARNING] STATS_PACK: payload must be a list - stats pack not written")
    return(invisible(NULL))
  }

  tryCatch({

    wb <- openxlsx::createWorkbook()
    openxlsx::modifyBaseFont(wb, fontName = "Calibri", fontSize = 11)

    # Write sheets in order
    sp_write_declaration_sheet(wb, payload)
    sp_write_data_used_sheet(wb, payload)
    sp_write_assumptions_sheet(wb, payload)
    sp_write_warnings_sheet(wb, payload)
    sp_write_reproducibility_sheet(wb, payload)
    sp_write_config_echo_sheet(wb, payload)

    # Protect all sheets if requested
    if (isTRUE(protect_sheets)) {
      for (sht in names(wb)) {
        openxlsx::protectWorksheet(wb, sht, protect = TRUE,
                                   lockSelectingLockedCells = FALSE,
                                   lockSelectingUnlockedCells = FALSE,
                                   lockFormattingCells = TRUE,
                                   lockFormattingColumns = TRUE,
                                   lockFormattingRows = TRUE,
                                   lockInsertingColumns = TRUE,
                                   lockInsertingRows = TRUE,
                                   lockDeletingColumns = TRUE,
                                   lockDeletingRows = TRUE)
      }
    }

    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

    message(sprintf("[TRS INFO] STATS_PACK: Written to %s", basename(output_path)))
    invisible(output_path)

  }, error = function(e) {
    message(sprintf("[TRS WARNING] STATS_PACK: Failed to write stats pack: %s", e$message))
    invisible(NULL)
  })
}


# ==============================================================================
# SHEET: DECLARATION
# ==============================================================================

#' Write Declaration Sheet
#' @keywords internal
sp_write_declaration_sheet <- function(wb, payload) {

  sheet <- "Declaration"
  openxlsx::addWorksheet(wb, sheet, gridLines = FALSE)

  # --- Styles ---
  title_style <- openxlsx::createStyle(
    fontSize = 16, textDecoration = "bold",
    fontColour = "#1e3a5f"
  )
  subtitle_style <- openxlsx::createStyle(
    fontSize = 11, fontColour = "#64748b"
  )
  section_style <- openxlsx::createStyle(
    fontSize = 11, textDecoration = "bold",
    fontColour = "#1e3a5f",
    border = "Bottom", borderColour = "#1e3a5f"
  )
  label_style <- openxlsx::createStyle(
    fontSize = 11, textDecoration = "bold",
    fontColour = "#374151"
  )
  value_style <- openxlsx::createStyle(
    fontSize = 11, fontColour = "#111827"
  )
  status_pass_style <- openxlsx::createStyle(
    fontSize = 11, textDecoration = "bold",
    fontColour = "#FFFFFF", fgFill = "#16a34a"
  )
  status_partial_style <- openxlsx::createStyle(
    fontSize = 11, textDecoration = "bold",
    fontColour = "#FFFFFF", fgFill = "#d97706"
  )
  status_refuse_style <- openxlsx::createStyle(
    fontSize = 11, textDecoration = "bold",
    fontColour = "#FFFFFF", fgFill = "#dc2626"
  )
  footer_style <- openxlsx::createStyle(
    fontSize = 9, fontColour = "#9ca3af"
  )

  row <- 1

  # Title
  openxlsx::writeData(wb, sheet, "TURAS ANALYTICS PLATFORM", startRow = row, startCol = 2)
  openxlsx::addStyle(wb, sheet, title_style, rows = row, cols = 2)
  row <- row + 1
  openxlsx::writeData(wb, sheet, "Statistical Diagnostics Pack", startRow = row, startCol = 2)
  openxlsx::addStyle(wb, sheet, subtitle_style, rows = row, cols = 2)
  row <- row + 2

  # Helper to write a key-value row
  write_kv <- function(key, value, row, label_col = 2, value_col = 4) {
    openxlsx::writeData(wb, sheet, key, startRow = row, startCol = label_col)
    openxlsx::addStyle(wb, sheet, label_style, rows = row, cols = label_col)
    openxlsx::writeData(wb, sheet, as.character(value %||% "—"), startRow = row, startCol = value_col)
    openxlsx::addStyle(wb, sheet, value_style, rows = row, cols = value_col)
    row + 1
  }

  write_section <- function(title, row) {
    openxlsx::writeData(wb, sheet, title, startRow = row, startCol = 2)
    openxlsx::addStyle(wb, sheet, section_style, rows = row, cols = 2)
    row + 1
  }

  # --- PROJECT SECTION ---
  row <- write_section("PROJECT", row)
  row <- row + 1  # blank line after underline
  row <- write_kv("Project",       payload$project_name,   row)
  row <- write_kv("Research House", payload$research_house, row)
  row <- write_kv("Analyst",       payload$analyst_name,   row)
  row <- write_kv("Module",        payload$module %||% "UNKNOWN", row)
  row <- row + 1

  # --- RUN INFO ---
  row <- write_section("RUN INFORMATION", row)
  row <- row + 1
  run_ts <- if (!is.null(payload$run_timestamp)) {
    format(payload$run_timestamp, "%Y-%m-%d %H:%M:%S")
  } else "—"
  row <- write_kv("Run Date / Time", run_ts, row)

  duration_str <- if (!is.null(payload$duration_seconds)) {
    sprintf("%.1f seconds", payload$duration_seconds)
  } else "—"
  row <- write_kv("Duration", duration_str, row)
  row <- write_kv("Turas Version",  payload$turas_version %||% "—", row)

  # Status with colour
  status_val <- payload$status %||% "UNKNOWN"
  openxlsx::writeData(wb, sheet, "Status", startRow = row, startCol = 2)
  openxlsx::addStyle(wb, sheet, label_style, rows = row, cols = 2)
  openxlsx::writeData(wb, sheet, status_val, startRow = row, startCol = 4)
  status_cell_style <- switch(status_val,
    "PASS"    = status_pass_style,
    "PARTIAL" = status_partial_style,
    status_refuse_style
  )
  openxlsx::addStyle(wb, sheet, status_cell_style, rows = row, cols = 4)
  row <- row + 2

  # --- DATA RECEIVED ---
  dr <- payload$data_receipt %||% list()
  row <- write_section("DATA RECEIVED", row)
  row <- row + 1
  row <- write_kv("Source File",            dr$file_name %||% "—", row)
  row <- write_kv("Respondents",            format(dr$n_rows %||% 0, big.mark = ","), row)
  row <- write_kv("Columns",               format(dr$n_cols %||% 0, big.mark = ","), row)
  row <- write_kv("Questions in Config",   format(dr$questions_in_config %||% 0, big.mark = ","), row)
  row <- row + 1

  # --- DATA USED ---
  du <- payload$data_used %||% list()
  row <- write_section("DATA USED IN ANALYSIS", row)
  row <- row + 1

  n_resp_used    <- du$n_respondents %||% dr$n_rows %||% 0
  n_excluded     <- du$n_excluded %||% 0
  q_analysed     <- du$questions_analysed %||% dr$questions_in_config %||% 0
  q_skipped      <- du$questions_skipped %||% 0

  resp_note <- if (n_excluded > 0) {
    sprintf("%s  (%s excluded — see Data_Used sheet for detail)",
            format(n_resp_used, big.mark = ","),
            format(n_excluded, big.mark = ","))
  } else {
    sprintf("%s  (no respondents excluded)", format(n_resp_used, big.mark = ","))
  }

  q_note <- if (q_skipped > 0) {
    sprintf("%s  (%s skipped — see Data_Used sheet for detail)",
            format(q_analysed, big.mark = ","),
            format(q_skipped, big.mark = ","))
  } else {
    sprintf("%s  (all questions analysed)", format(q_analysed, big.mark = ","))
  }

  row <- write_kv("Respondents Analysed",  resp_note, row)
  row <- write_kv("Questions Analysed",    q_note, row)

  # Weighting note
  weight_note <- if (!is.null(du$weight_variable) && du$weight_variable != "") {
    sprintf("Yes — weight variable: %s", du$weight_variable)
  } else if (isTRUE(du$weighted)) {
    "Yes"
  } else {
    "No — unweighted analysis"
  }
  row <- write_kv("Weighting", weight_note, row)
  row <- row + 1

  # --- FOOTER ---
  footer_text <- paste0(
    "This document was automatically generated by Turas Analytics Platform. ",
    "All figures reflect the data and configuration as loaded at run time. ",
    "See individual sheets for full detail."
  )
  openxlsx::writeData(wb, sheet, footer_text, startRow = row + 2, startCol = 2)
  openxlsx::addStyle(wb, sheet, footer_style, rows = row + 2, cols = 2)

  # Column widths
  openxlsx::setColWidths(wb, sheet, cols = 1, widths = 2)     # left margin
  openxlsx::setColWidths(wb, sheet, cols = 2, widths = 26)    # labels
  openxlsx::setColWidths(wb, sheet, cols = 3, widths = 2)     # gap
  openxlsx::setColWidths(wb, sheet, cols = 4, widths = 60)    # values

  invisible(TRUE)
}


# ==============================================================================
# SHEET: DATA USED
# ==============================================================================

#' Write Data Used Sheet
#' @keywords internal
sp_write_data_used_sheet <- function(wb, payload) {

  sheet <- "Data_Used"
  openxlsx::addWorksheet(wb, sheet, gridLines = TRUE)

  du  <- payload$data_used %||% list()
  row <- 1

  header_style <- openxlsx::createStyle(
    fontSize = 12, textDecoration = "bold", fontColour = "#1e3a5f"
  )
  table_header_style <- openxlsx::createStyle(
    textDecoration = "bold", fgFill = "#dbeafe",
    border = "TopBottom", borderColour = "#93c5fd"
  )

  # Per-item stats table
  openxlsx::writeData(wb, sheet, "Response Counts by Question", startRow = row, startCol = 1)
  openxlsx::addStyle(wb, sheet, header_style, rows = row, cols = 1)
  row <- row + 1

  if (!is.null(du$per_item_stats) && is.data.frame(du$per_item_stats) &&
      nrow(du$per_item_stats) > 0) {

    openxlsx::writeData(wb, sheet, du$per_item_stats,
                        startRow = row, startCol = 1,
                        withFilter = TRUE,
                        headerStyle = table_header_style)

    # Highlight any high-missing rows (>10%)
    if ("Missing_Pct" %in% names(du$per_item_stats)) {
      warn_style <- openxlsx::createStyle(fgFill = "#fef9c3")  # pale yellow
      for (i in seq_len(nrow(du$per_item_stats))) {
        if (!is.na(du$per_item_stats$Missing_Pct[i]) &&
            du$per_item_stats$Missing_Pct[i] > 10) {
          openxlsx::addStyle(wb, sheet, warn_style,
                             rows = row + i,
                             cols = seq_len(ncol(du$per_item_stats)),
                             gridExpand = TRUE)
        }
      }
    }

    row <- row + nrow(du$per_item_stats) + 2

  } else {
    openxlsx::writeData(wb, sheet, "No per-item statistics available.",
                        startRow = row, startCol = 1)
    row <- row + 2
  }

  # Exclusions detail (if any)
  if (!is.null(du$exclusions_detail) && is.data.frame(du$exclusions_detail) &&
      nrow(du$exclusions_detail) > 0) {

    openxlsx::writeData(wb, sheet, "Exclusions Detail", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet, header_style, rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, sheet, du$exclusions_detail,
                        startRow = row, startCol = 1,
                        withFilter = TRUE,
                        headerStyle = table_header_style)
    row <- row + nrow(du$exclusions_detail) + 2
  }

  # Skipped questions (if any)
  if (!is.null(du$skipped_questions_detail) &&
      length(du$skipped_questions_detail) > 0) {

    skipped_df <- do.call(rbind, lapply(
      names(du$skipped_questions_detail),
      function(qid) {
        entry <- du$skipped_questions_detail[[qid]]
        data.frame(
          Question_ID = qid,
          Reason      = entry$reason %||% "—",
          stringsAsFactors = FALSE
        )
      }
    ))

    openxlsx::writeData(wb, sheet, "Skipped Questions", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet, header_style, rows = row, cols = 1)
    row <- row + 1

    openxlsx::writeData(wb, sheet, skipped_df,
                        startRow = row, startCol = 1,
                        headerStyle = table_header_style)
  }

  openxlsx::setColWidths(wb, sheet, cols = 1:6, widths = "auto")

  invisible(TRUE)
}


# ==============================================================================
# SHEET: ASSUMPTIONS
# ==============================================================================

#' Write Assumptions Sheet
#' @keywords internal
sp_write_assumptions_sheet <- function(wb, payload) {

  sheet <- "Assumptions"
  openxlsx::addWorksheet(wb, sheet, gridLines = TRUE)

  assumptions <- payload$assumptions %||% list()

  if (length(assumptions) == 0) {
    openxlsx::writeData(wb, sheet, "No assumptions recorded.", startRow = 1, startCol = 1)
    return(invisible(TRUE))
  }

  header_style <- openxlsx::createStyle(
    textDecoration = "bold", fgFill = "#dbeafe",
    border = "TopBottom", borderColour = "#93c5fd"
  )

  # Flatten named list to data frame
  params_df <- data.frame(
    Parameter = names(assumptions),
    Value     = vapply(assumptions, function(x) {
      if (is.null(x) || (length(x) == 1 && is.na(x))) "—"
      else paste(as.character(x), collapse = "; ")
    }, character(1)),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, sheet, params_df,
                      startRow = 1, startCol = 1,
                      withFilter = FALSE,
                      headerStyle = header_style)

  openxlsx::setColWidths(wb, sheet, cols = 1, widths = 35)
  openxlsx::setColWidths(wb, sheet, cols = 2, widths = 55)

  invisible(TRUE)
}


# ==============================================================================
# SHEET: WARNINGS
# ==============================================================================

#' Write Warnings Sheet (delegates to TRS run_result events)
#' @keywords internal
sp_write_warnings_sheet <- function(wb, payload) {

  sheet <- "Warnings"
  openxlsx::addWorksheet(wb, sheet, gridLines = TRUE)

  run_result <- payload$run_result

  header_style <- openxlsx::createStyle(
    textDecoration = "bold", fgFill = "#dbeafe",
    border = "TopBottom", borderColour = "#93c5fd"
  )

  if (is.null(run_result) || length(run_result$events) == 0) {
    openxlsx::writeData(wb, sheet,
                        "No warnings or events recorded — analysis completed cleanly.",
                        startRow = 1, startCol = 1)
    return(invisible(TRUE))
  }

  events_df <- do.call(rbind, lapply(run_result$events, function(e) {
    data.frame(
      Level    = e$level    %||% NA_character_,
      Code     = e$code     %||% NA_character_,
      Title    = e$title    %||% NA_character_,
      Question = e$question_code %||% NA_character_,
      Detail   = e$detail   %||% NA_character_,
      Fix      = e$fix      %||% NA_character_,
      stringsAsFactors = FALSE
    )
  }))

  openxlsx::writeData(wb, sheet, events_df,
                      startRow = 1, startCol = 1,
                      withFilter = TRUE,
                      headerStyle = header_style)

  # Colour Level column
  level_info_style    <- openxlsx::createStyle(fgFill = "#dbeafe", fontColour = "#1d4ed8")
  level_partial_style <- openxlsx::createStyle(fgFill = "#fef9c3", fontColour = "#92400e")
  level_error_style   <- openxlsx::createStyle(fgFill = "#fee2e2", fontColour = "#991b1b")

  for (i in seq_len(nrow(events_df))) {
    sty <- switch(events_df$Level[i],
      "INFO"    = level_info_style,
      "PARTIAL" = level_partial_style,
      level_error_style
    )
    openxlsx::addStyle(wb, sheet, sty, rows = i + 1, cols = 1)
  }

  openxlsx::setColWidths(wb, sheet, cols = 1:6,
                         widths = c(10, 30, 35, 15, 55, 55))

  invisible(TRUE)
}


# ==============================================================================
# SHEET: REPRODUCIBILITY
# ==============================================================================

#' Write Reproducibility Sheet
#' @keywords internal
sp_write_reproducibility_sheet <- function(wb, payload) {

  sheet <- "Reproducibility"
  openxlsx::addWorksheet(wb, sheet, gridLines = TRUE)

  header_style <- openxlsx::createStyle(
    fontSize = 11, textDecoration = "bold", fontColour = "#1e3a5f"
  )
  table_header_style <- openxlsx::createStyle(
    textDecoration = "bold", fgFill = "#dbeafe",
    border = "TopBottom", borderColour = "#93c5fd"
  )

  row <- 1

  # --- Environment ---
  openxlsx::writeData(wb, sheet, "Environment", startRow = row, startCol = 1)
  openxlsx::addStyle(wb, sheet, header_style, rows = row, cols = 1)
  row <- row + 1

  env_df <- data.frame(
    Item  = c("Turas Version", "R Version", "Platform", "Run Timestamp"),
    Value = c(
      payload$turas_version %||% "—",
      payload$r_version %||% R.version$version.string,
      paste(R.version$os, R.version$arch),
      if (!is.null(payload$run_timestamp)) {
        format(payload$run_timestamp, "%Y-%m-%d %H:%M:%S")
      } else "—"
    ),
    stringsAsFactors = FALSE
  )

  openxlsx::writeData(wb, sheet, env_df, startRow = row, startCol = 1,
                      headerStyle = table_header_style)
  row <- row + nrow(env_df) + 2

  # --- Seeds ---
  if (!is.null(payload$seeds) && length(payload$seeds) > 0) {

    openxlsx::writeData(wb, sheet, "Random Seeds", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet, header_style, rows = row, cols = 1)
    row <- row + 1

    seeds_df <- data.frame(
      Context = names(payload$seeds),
      Seed    = vapply(payload$seeds, as.character, character(1)),
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, sheet, seeds_df, startRow = row, startCol = 1,
                        headerStyle = table_header_style)
    row <- row + nrow(seeds_df) + 2
  }

  # --- Packages ---
  pkg_names <- payload$packages
  if (!is.null(pkg_names) && length(pkg_names) > 0) {

    openxlsx::writeData(wb, sheet, "Packages Used", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet, header_style, rows = row, cols = 1)
    row <- row + 1

    pkg_versions <- vapply(pkg_names, function(p) {
      tryCatch(as.character(utils::packageVersion(p)), error = function(e) "not installed")
    }, character(1))

    pkg_df <- data.frame(
      Package = pkg_names,
      Version = pkg_versions,
      stringsAsFactors = FALSE
    )

    openxlsx::writeData(wb, sheet, pkg_df, startRow = row, startCol = 1,
                        headerStyle = table_header_style)
  }

  openxlsx::setColWidths(wb, sheet, cols = 1, widths = 30)
  openxlsx::setColWidths(wb, sheet, cols = 2, widths = 40)

  invisible(TRUE)
}


# ==============================================================================
# SHEET: CONFIG ECHO
# ==============================================================================

#' Write Config Echo Sheet
#' @keywords internal
sp_write_config_echo_sheet <- function(wb, payload) {

  sheet <- "Config_Echo"
  openxlsx::addWorksheet(wb, sheet, gridLines = TRUE)

  config <- payload$config_echo

  if (is.null(config)) {
    openxlsx::writeData(wb, sheet, "No configuration data available.",
                        startRow = 1, startCol = 1)
    return(invisible(TRUE))
  }

  header_style <- openxlsx::createStyle(
    fontSize = 11, textDecoration = "bold", fontColour = "#1e3a5f"
  )
  table_header_style <- openxlsx::createStyle(
    textDecoration = "bold", fgFill = "#dbeafe",
    border = "TopBottom", borderColour = "#93c5fd"
  )

  row <- 1

  # Walk top-level config elements and write each as a table
  for (section_name in names(config)) {

    section <- config[[section_name]]

    openxlsx::writeData(wb, sheet, section_name, startRow = row, startCol = 1)
    openxlsx::addStyle(wb, sheet, header_style, rows = row, cols = 1)
    row <- row + 1

    if (is.data.frame(section)) {
      # Write as-is
      openxlsx::writeData(wb, sheet, section,
                          startRow = row, startCol = 1,
                          headerStyle = table_header_style)
      row <- row + nrow(section) + 2

    } else if (is.list(section)) {
      # Flatten to key-value
      kv_df <- data.frame(
        Setting = names(section),
        Value   = vapply(section, function(x) {
          if (is.null(x) || (length(x) == 1 && is.na(x))) "—"
          else paste(as.character(x), collapse = "; ")
        }, character(1)),
        stringsAsFactors = FALSE
      )
      openxlsx::writeData(wb, sheet, kv_df,
                          startRow = row, startCol = 1,
                          headerStyle = table_header_style)
      row <- row + nrow(kv_df) + 2

    } else {
      openxlsx::writeData(wb, sheet, as.character(section),
                          startRow = row, startCol = 1)
      row <- row + 2
    }
  }

  openxlsx::setColWidths(wb, sheet, cols = 1, widths = 35)
  openxlsx::setColWidths(wb, sheet, cols = 2, widths = 55)

  invisible(TRUE)
}


# ==============================================================================
# HELPERS
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}
