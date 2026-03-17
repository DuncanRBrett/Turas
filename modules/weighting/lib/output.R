# ==============================================================================
# WEIGHTING MODULE - OUTPUT FUNCTIONS
# ==============================================================================
# Functions for writing weighted data and generating reports
# Part of TURAS Weighting Module v3.0
# ==============================================================================

# Brand colours for Excel formatting
TURAS_BRAND_BLUE <- "#1e3a5f"
TURAS_ACCENT_TEAL <- "#2aa198"
TURAS_GOOD_GREEN <- "#27ae60"
TURAS_WARN_AMBER <- "#f39c12"
TURAS_POOR_RED <- "#e74c3c"
TURAS_LIGHT_GREY <- "#f5f5f5"

#' Write Weighted Data
#'
#' Writes the weighted data to a file (CSV or Excel).
#'
#' @param data Data frame with weight column(s) added
#' @param output_file Character, path to output file
#' @param verbose Logical, print progress
#' @return Invisible path to written file
#' @export
write_weighted_data <- function(data, output_file, verbose = TRUE) {

  if (is.null(output_file) || is.na(output_file) || output_file == "") {
    if (verbose) {
      message("No output file specified - data returned to R environment only")
    }
    return(invisible(NULL))
  }

  # Ensure directory exists
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Determine format from extension
  file_ext <- tolower(tools::file_ext(output_file))

  if (verbose) {
    message("\nWriting weighted data...")
    message("  Output file: ", basename(output_file))
    message("  Format: ", toupper(file_ext))
    message("  Rows: ", nrow(data))
    message("  Columns: ", ncol(data))
  }

  tryCatch({
    if (file_ext == "csv") {
      write.csv(data, output_file, row.names = FALSE)
    } else if (file_ext %in% c("xlsx", "xls")) {
      if (!requireNamespace("openxlsx", quietly = TRUE)) {
        weighting_refuse(
          code = "PKG_OPENXLSX_MISSING",
          title = "Required Package Not Installed",
          problem = "The 'openxlsx' package is required for Excel output but is not installed.",
          why_it_matters = "Cannot write weighted data to Excel format without this package.",
          how_to_fix = c(
            "Install the package: install.packages('openxlsx')",
            "Or use CSV format instead (change output_file extension to .csv)"
          )
        )
      }

      # TRS v1.0: Use atomic save to prevent file corruption on network/OneDrive folders
      if (exists("turas_save_workbook_atomic", mode = "function")) {
        wb <- openxlsx::createWorkbook()
        openxlsx::addWorksheet(wb, "Weighted_Data")
        openxlsx::writeData(wb, "Weighted_Data", data, rowNames = FALSE)

        save_result <- turas_save_workbook_atomic(wb, output_file, module = "WEIGHTING")
        if (!save_result$success) {
          weighting_refuse(
            code = "IO_ATOMIC_SAVE_FAILED",
            title = "Failed to Save Weighted Data File",
            problem = sprintf("Atomic save failed for: %s", output_file),
            why_it_matters = "Weighted data was calculated but could not be saved safely.",
            how_to_fix = c(
              "Check directory permissions",
              "Ensure file is not open in another program",
              "Verify disk space is available"
            ),
            details = save_result$error
          )
        }
      } else {
        weighting_refuse(
          code = "IO_ATOMIC_SAVE_UNAVAILABLE",
          title = "Atomic Save Not Available",
          problem = "The turas_save_workbook_atomic function is required but not loaded.",
          why_it_matters = "Direct file saves risk corruption on network/OneDrive-synced folders.",
          how_to_fix = c(
            "Ensure Turas shared library is accessible",
            "Verify modules/shared/lib/turas_save_workbook_atomic.R exists",
            "Contact support if the problem persists"
          )
        )
      }
    } else {
      weighting_refuse(
        code = "IO_UNSUPPORTED_FORMAT",
        title = "Unsupported Output Format",
        problem = sprintf("Cannot write to format: .%s", file_ext),
        why_it_matters = "Data cannot be saved in unsupported formats.",
        how_to_fix = c(
          "Use a supported format: .csv or .xlsx",
          "Change the output_file extension in your config"
        )
      )
    }

    if (verbose) {
      message("  Data written successfully")
    }

    return(invisible(output_file))

  }, turas_refusal = function(e) {
    # Re-signal TRS refusals with their original code (don't wrap in generic IO error)
    stop(e)
  }, error = function(e) {
    weighting_refuse(
      code = "IO_WRITE_FAILED",
      title = "Failed to Write Output File",
      problem = sprintf("Could not write weighted data to: %s", output_file),
      why_it_matters = "Weighted data was calculated but could not be saved.",
      how_to_fix = c(
        "Check directory permissions",
        "Ensure file is not open in another program",
        "Verify disk space is available"
      ),
      details = conditionMessage(e)
    )
  })
}

#' Generate Full Weighting Report
#'
#' Generates a comprehensive weighting report including all diagnostics.
#'
#' @param weighting_results List, results from run_weighting
#' @param output_file Character, path to output report file
#' @param run_state Environment, TRS run state for Run_Status sheet (optional)
#' @param verbose Logical, print progress
#' @return Invisible path to written file
#' @export
generate_weighting_report <- function(weighting_results, output_file,
                                      run_state = NULL, verbose = TRUE) {

  if (verbose) {
    message("\nGenerating weighting report...")
  }

  # Build report content
  report_lines <- character(0)

  # Header
  report_lines <- c(report_lines,
    strrep("=", 80),
    "TURAS WEIGHTING MODULE - ANALYSIS REPORT",
    strrep("=", 80),
    "",
    paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    paste("Project:", weighting_results$config$general$project_name),
    paste("Data file:", basename(weighting_results$config$general$data_file)),
    paste("Config file:", basename(weighting_results$config$config_file)),
    ""
  )

  # Summary section
  report_lines <- c(report_lines,
    strrep("-", 80),
    "SUMMARY",
    strrep("-", 80),
    "",
    paste("Total records:", nrow(weighting_results$data)),
    paste("Weight columns created:", length(weighting_results$weight_names)),
    paste("Weight names:", paste(weighting_results$weight_names, collapse = ", ")),
    ""
  )

  # Per-weight details
  for (weight_name in weighting_results$weight_names) {
    result <- weighting_results$weight_results[[weight_name]]

    report_lines <- c(report_lines,
      strrep("=", 80),
      paste("WEIGHT:", weight_name),
      strrep("=", 80),
      ""
    )

    # Method info
    spec <- weighting_results$config$weight_specifications
    spec_row <- spec[spec$weight_name == weight_name, ]
    report_lines <- c(report_lines,
      paste("Method:", spec_row$method[1]),
      ""
    )

    # Add diagnostics output
    if (!is.null(result$diagnostics)) {
      diag <- result$diagnostics

      report_lines <- c(report_lines,
        "SAMPLE SIZE:",
        paste("  Total cases:", diag$sample_size$n_total),
        paste("  Valid weights:", diag$sample_size$n_valid),
        paste("  Invalid (NA/zero):", diag$sample_size$n_na + diag$sample_size$n_zero),
        ""
      )

      report_lines <- c(report_lines,
        "WEIGHT DISTRIBUTION:",
        sprintf("  Min: %.4f", diag$distribution$min),
        sprintf("  Q1: %.4f", diag$distribution$q1),
        sprintf("  Median: %.4f", diag$distribution$median),
        sprintf("  Q3: %.4f", diag$distribution$q3),
        sprintf("  Max: %.4f", diag$distribution$max),
        sprintf("  Mean: %.4f", diag$distribution$mean),
        sprintf("  SD: %.4f", diag$distribution$sd),
        sprintf("  CV: %.4f", diag$distribution$cv),
        ""
      )

      report_lines <- c(report_lines,
        "EFFECTIVE SAMPLE SIZE:",
        sprintf("  Effective N: %d", diag$effective_sample$effective_n),
        sprintf("  Design effect: %.2f", diag$effective_sample$design_effect),
        sprintf("  Efficiency: %.1f%%", diag$effective_sample$efficiency),
        ""
      )

      report_lines <- c(report_lines,
        "QUALITY ASSESSMENT:",
        paste("  Status:", diag$quality$status),
        ""
      )

      if (length(diag$quality$issues) > 0) {
        report_lines <- c(report_lines, "  Issues:")
        for (issue in diag$quality$issues) {
          report_lines <- c(report_lines, paste("    -", issue))
        }
        report_lines <- c(report_lines, "")
      }
    }

    # Rim weighting specifics
    if (!is.null(result$rim_result) && !is.null(result$rim_result$margins)) {
      report_lines <- c(report_lines,
        "RIM TARGET ACHIEVEMENT:",
        sprintf("  %-12s %-15s %10s %10s %10s",
                "Variable", "Category", "Target%", "Achieved%", "Diff%"),
        strrep("-", 60)
      )

      margins <- result$rim_result$margins
      for (i in seq_len(nrow(margins))) {
        row <- margins[i, ]
        report_lines <- c(report_lines,
          sprintf("  %-12s %-15s %10.1f %10.1f %+10.1f",
                  row$variable, row$category,
                  row$target_pct, row$achieved_pct, row$diff_pct)
        )
      }
      report_lines <- c(report_lines, "")
    }

    # Design weight specifics
    if (!is.null(result$design_result) && !is.null(result$design_result$stratum_summary)) {
      report_lines <- c(report_lines,
        "STRATUM DETAILS:",
        sprintf("  %-20s %12s %12s %12s",
                "Stratum", "Population", "Sample", "Weight"),
        strrep("-", 60)
      )

      strata <- result$design_result$stratum_summary
      for (i in seq_len(nrow(strata))) {
        row <- strata[i, ]
        report_lines <- c(report_lines,
          sprintf("  %-20s %12s %12d %12.4f",
                  row$stratum,
                  format(row$population_size, big.mark = ","),
                  row$sample_size,
                  row$weight)
        )
      }
      report_lines <- c(report_lines, "")
    }

    report_lines <- c(report_lines, "")
  }

  # Footer
  report_lines <- c(report_lines,
    strrep("=", 80),
    "END OF REPORT",
    strrep("=", 80)
  )

  # Write report based on file extension
  file_ext <- tolower(tools::file_ext(output_file))

  tryCatch({
    if (file_ext == "txt" || file_ext == "") {
      # Plain text report
      writeLines(report_lines, output_file)

    } else if (file_ext %in% c("xlsx", "xls")) {
      # Excel report - convert to structured tables
      if (!requireNamespace("openxlsx", quietly = TRUE)) {
        weighting_refuse(
          code = "PKG_OPENXLSX_MISSING",
          title = "Required Package Not Installed",
          problem = "The 'openxlsx' package is required for Excel diagnostics but is not installed.",
          why_it_matters = "Cannot write diagnostics report to Excel format without this package.",
          how_to_fix = c(
            "Install the package: install.packages('openxlsx')",
            "Or use .txt format instead for plain text report"
          )
        )
      }

      wb <- openxlsx::createWorkbook()

      # Define reusable styles
      style_title <- openxlsx::createStyle(
        fontSize = 14, fontColour = TURAS_BRAND_BLUE,
        textDecoration = "bold"
      )
      style_section <- openxlsx::createStyle(
        fontSize = 11, fontColour = TURAS_BRAND_BLUE,
        textDecoration = "bold", border = "bottom",
        borderColour = TURAS_ACCENT_TEAL
      )
      style_header <- openxlsx::createStyle(
        fontSize = 10, textDecoration = "bold",
        fgFill = TURAS_BRAND_BLUE, fontColour = "#FFFFFF",
        halign = "center"
      )
      style_number_4dp <- openxlsx::createStyle(numFmt = "0.0000")
      style_number_2dp <- openxlsx::createStyle(numFmt = "0.00")
      style_pct_1dp <- openxlsx::createStyle(numFmt = "0.0")
      style_good <- openxlsx::createStyle(fontColour = TURAS_GOOD_GREEN, textDecoration = "bold")
      style_warn <- openxlsx::createStyle(fontColour = TURAS_WARN_AMBER, textDecoration = "bold")
      style_poor <- openxlsx::createStyle(fontColour = TURAS_POOR_RED, textDecoration = "bold")
      style_stripe <- openxlsx::createStyle(fgFill = TURAS_LIGHT_GREY)

      # Escape user text for Excel formula injection
      escape_text <- if (exists("turas_excel_escape", mode = "function")) {
        turas_excel_escape
      } else {
        function(x) x
      }

      # ---- Summary sheet ----
      openxlsx::addWorksheet(wb, "Summary")
      r <- 1

      openxlsx::writeData(wb, "Summary", "TURAS Weighting Report", startRow = r, startCol = 1)
      openxlsx::addStyle(wb, "Summary", style_title, rows = r, cols = 1)
      r <- r + 2

      project_name <- escape_text(weighting_results$config$general$project_name)
      info_df <- data.frame(
        Setting = c("Project", "Generated", "Data File", "Config File", "Total Records"),
        Value = c(
          project_name,
          format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
          basename(weighting_results$config$general$data_file),
          basename(weighting_results$config$config_file),
          as.character(nrow(weighting_results$data))
        ),
        stringsAsFactors = FALSE
      )
      openxlsx::writeData(wb, "Summary", info_df, startRow = r, headerStyle = style_header)
      r <- r + nrow(info_df) + 2

      # Weight summary table
      openxlsx::writeData(wb, "Summary", "Weight Summary", startRow = r, startCol = 1)
      openxlsx::addStyle(wb, "Summary", style_section, rows = r, cols = 1:7, gridExpand = TRUE)
      r <- r + 1

      summary_df <- create_weight_summary_df(weighting_results)
      if (nrow(summary_df) > 0) {
        openxlsx::writeData(wb, "Summary", summary_df, startRow = r, headerStyle = style_header)

        # Format number columns
        n_rows <- nrow(summary_df)
        data_rows <- (r + 1):(r + n_rows)
        openxlsx::addStyle(wb, "Summary", style_number_4dp, rows = data_rows, cols = 5:8, gridExpand = TRUE)
        openxlsx::addStyle(wb, "Summary", style_number_2dp, rows = data_rows, cols = 10, gridExpand = TRUE)
        openxlsx::addStyle(wb, "Summary", style_pct_1dp, rows = data_rows, cols = 11, gridExpand = TRUE)

        # Conditional formatting for quality status
        for (i in seq_len(n_rows)) {
          status <- summary_df$quality_status[i]
          quality_style <- if (status == "GOOD") style_good
                          else if (status == "ACCEPTABLE") style_warn
                          else style_poor
          openxlsx::addStyle(wb, "Summary", quality_style, rows = r + i, cols = 12)
        }

        # Zebra striping
        for (i in seq_along(data_rows)) {
          if (i %% 2 == 0) {
            openxlsx::addStyle(wb, "Summary", style_stripe, rows = data_rows[i], cols = 1:12, gridExpand = TRUE, stack = TRUE)
          }
        }

        r <- r + n_rows + 2
      }

      # Auto-size columns and freeze panes
      openxlsx::setColWidths(wb, "Summary", cols = 1:12, widths = "auto")
      openxlsx::freezePane(wb, "Summary", firstRow = TRUE)

      # ---- Per-weight sheets ----
      for (weight_name in weighting_results$weight_names) {
        result <- weighting_results$weight_results[[weight_name]]
        sheet_name <- gsub("[^A-Za-z0-9_]", "_", weight_name)
        sheet_name <- substr(sheet_name, 1, 31)

        openxlsx::addWorksheet(wb, sheet_name)
        row_num <- 1

        # Weight header
        openxlsx::writeData(wb, sheet_name, weight_name, startCol = 1, startRow = row_num)
        openxlsx::addStyle(wb, sheet_name, style_title, rows = row_num, cols = 1)
        row_num <- row_num + 1

        # Method
        spec <- weighting_results$config$weight_specifications
        method <- spec$method[spec$weight_name == weight_name]
        openxlsx::writeData(wb, sheet_name, paste("Method:", method), startCol = 1, startRow = row_num)
        row_num <- row_num + 2

        # Diagnostics tables
        if (!is.null(result$diagnostics)) {
          diag <- result$diagnostics

          # Sample size
          openxlsx::writeData(wb, sheet_name, "Sample Size", startCol = 1, startRow = row_num)
          openxlsx::addStyle(wb, sheet_name, style_section, rows = row_num, cols = 1:2, gridExpand = TRUE)
          row_num <- row_num + 1
          sample_df <- data.frame(
            Metric = c("Total cases", "Valid weights", "NA weights", "Zero weights"),
            Value = c(diag$sample_size$n_total, diag$sample_size$n_valid,
                     diag$sample_size$n_na, diag$sample_size$n_zero)
          )
          openxlsx::writeData(wb, sheet_name, sample_df, startRow = row_num, headerStyle = style_header)
          row_num <- row_num + nrow(sample_df) + 2

          # Weight distribution
          openxlsx::writeData(wb, sheet_name, "Weight Distribution", startCol = 1, startRow = row_num)
          openxlsx::addStyle(wb, sheet_name, style_section, rows = row_num, cols = 1:2, gridExpand = TRUE)
          row_num <- row_num + 1
          dist_df <- data.frame(
            Statistic = c("Min", "Q1", "Median", "Q3", "Max", "Mean", "SD", "CV"),
            Value = c(diag$distribution$min, diag$distribution$q1, diag$distribution$median,
                     diag$distribution$q3, diag$distribution$max, diag$distribution$mean,
                     diag$distribution$sd, diag$distribution$cv)
          )
          openxlsx::writeData(wb, sheet_name, dist_df, startRow = row_num, headerStyle = style_header)
          # Format values to 4dp
          openxlsx::addStyle(wb, sheet_name, style_number_4dp,
                            rows = (row_num + 1):(row_num + nrow(dist_df)),
                            cols = 2, gridExpand = TRUE)
          row_num <- row_num + nrow(dist_df) + 2

          # Effective sample size
          openxlsx::writeData(wb, sheet_name, "Effective Sample Size", startCol = 1, startRow = row_num)
          openxlsx::addStyle(wb, sheet_name, style_section, rows = row_num, cols = 1:2, gridExpand = TRUE)
          row_num <- row_num + 1
          eff_df <- data.frame(
            Metric = c("Effective N", "Design Effect (DEFF)", "Weighting Efficiency"),
            Value = c(
              diag$effective_sample$effective_n,
              round(diag$effective_sample$design_effect, 2),
              paste0(round(diag$effective_sample$efficiency, 1), "%")
            )
          )
          openxlsx::writeData(wb, sheet_name, eff_df, startRow = row_num, headerStyle = style_header)
          row_num <- row_num + nrow(eff_df) + 2

          # Quality assessment with colour
          openxlsx::writeData(wb, sheet_name, "Quality Assessment", startCol = 1, startRow = row_num)
          openxlsx::addStyle(wb, sheet_name, style_section, rows = row_num, cols = 1:2, gridExpand = TRUE)
          row_num <- row_num + 1
          openxlsx::writeData(wb, sheet_name,
                             data.frame(Status = diag$quality$status),
                             startRow = row_num, headerStyle = style_header)
          quality_style <- if (diag$quality$status == "GOOD") style_good
                          else if (diag$quality$status == "ACCEPTABLE") style_warn
                          else style_poor
          openxlsx::addStyle(wb, sheet_name, quality_style, rows = row_num + 1, cols = 1)

          if (length(diag$quality$issues) > 0) {
            row_num <- row_num + 2
            openxlsx::writeData(wb, sheet_name, "Issues:", startCol = 1, startRow = row_num)
            for (issue in diag$quality$issues) {
              row_num <- row_num + 1
              openxlsx::writeData(wb, sheet_name, paste("-", issue), startCol = 1, startRow = row_num)
            }
          }
          row_num <- row_num + 3
        }

        # Rim margins
        if (!is.null(result$rim_result) && !is.null(result$rim_result$margins)) {
          openxlsx::writeData(wb, sheet_name, "Rim Target Achievement", startCol = 1, startRow = row_num)
          openxlsx::addStyle(wb, sheet_name, style_section, rows = row_num, cols = 1:5, gridExpand = TRUE)
          row_num <- row_num + 1
          margins <- result$rim_result$margins
          openxlsx::writeData(wb, sheet_name, margins, startRow = row_num, headerStyle = style_header)
          # Format percentage columns
          n_margins <- nrow(margins)
          openxlsx::addStyle(wb, sheet_name, style_pct_1dp,
                            rows = (row_num + 1):(row_num + n_margins),
                            cols = 3:5, gridExpand = TRUE)
          row_num <- row_num + n_margins + 2
        }

        # Design stratum details
        if (!is.null(result$design_result) && !is.null(result$design_result$stratum_summary)) {
          openxlsx::writeData(wb, sheet_name, "Stratum Details", startCol = 1, startRow = row_num)
          openxlsx::addStyle(wb, sheet_name, style_section, rows = row_num, cols = 1:4, gridExpand = TRUE)
          row_num <- row_num + 1
          strata <- result$design_result$stratum_summary
          openxlsx::writeData(wb, sheet_name, strata, startRow = row_num, headerStyle = style_header)
          openxlsx::addStyle(wb, sheet_name, style_number_4dp,
                            rows = (row_num + 1):(row_num + nrow(strata)),
                            cols = 4, gridExpand = TRUE)
          row_num <- row_num + nrow(strata) + 2
        }

        # Cell weight details
        if (!is.null(result$cell_result) && !is.null(result$cell_result$cell_summary)) {
          openxlsx::writeData(wb, sheet_name, "Cell Details", startCol = 1, startRow = row_num)
          openxlsx::addStyle(wb, sheet_name, style_section, rows = row_num, cols = 1:5, gridExpand = TRUE)
          row_num <- row_num + 1
          cells <- result$cell_result$cell_summary
          openxlsx::writeData(wb, sheet_name, cells, startRow = row_num, headerStyle = style_header)
          n_cells <- nrow(cells)
          openxlsx::addStyle(wb, sheet_name, style_pct_1dp,
                            rows = (row_num + 1):(row_num + n_cells),
                            cols = 2:4, gridExpand = TRUE)
          openxlsx::addStyle(wb, sheet_name, style_number_4dp,
                            rows = (row_num + 1):(row_num + n_cells),
                            cols = 5, gridExpand = TRUE)
          row_num <- row_num + n_cells + 2
        }

        # Auto-size and freeze
        openxlsx::setColWidths(wb, sheet_name, cols = 1:6, widths = "auto")
        openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
      }

      # ---- Configuration sheet ----
      openxlsx::addWorksheet(wb, "Configuration")
      r <- 1
      openxlsx::writeData(wb, "Configuration", "Configuration Summary", startRow = r)
      openxlsx::addStyle(wb, "Configuration", style_title, rows = r, cols = 1)
      r <- r + 2

      # General settings
      gen <- weighting_results$config$general
      config_df <- data.frame(
        Setting = c("Project Name", "Data File", "Config File",
                    "Save Diagnostics", "Output File"),
        Value = c(
          escape_text(gen$project_name),
          basename(gen$data_file),
          basename(weighting_results$config$config_file),
          if (isTRUE(gen$save_diagnostics)) "Yes" else "No",
          if (!is.null(gen$output_file_resolved)) basename(gen$output_file_resolved) else "N/A"
        ),
        stringsAsFactors = FALSE
      )
      openxlsx::writeData(wb, "Configuration", "General Settings", startRow = r)
      openxlsx::addStyle(wb, "Configuration", style_section, rows = r, cols = 1:2, gridExpand = TRUE)
      r <- r + 1
      openxlsx::writeData(wb, "Configuration", config_df, startRow = r, headerStyle = style_header)
      r <- r + nrow(config_df) + 2

      # Weight specifications
      openxlsx::writeData(wb, "Configuration", "Weight Specifications", startRow = r)
      openxlsx::addStyle(wb, "Configuration", style_section, rows = r, cols = 1:6, gridExpand = TRUE)
      r <- r + 1
      specs <- weighting_results$config$weight_specifications
      openxlsx::writeData(wb, "Configuration", specs, startRow = r, headerStyle = style_header)
      r <- r + nrow(specs) + 2

      openxlsx::setColWidths(wb, "Configuration", cols = 1:6, widths = "auto")

      # ---- Notes sheet (if notes/assumptions provided) ----
      if (!is.null(weighting_results$config$notes) &&
          nrow(weighting_results$config$notes) > 0) {
        openxlsx::addWorksheet(wb, "Notes")
        r <- 1
        openxlsx::writeData(wb, "Notes", "Method Notes & Assumptions", startRow = r)
        openxlsx::addStyle(wb, "Notes", style_title, rows = r, cols = 1)
        r <- r + 2

        notes <- weighting_results$config$notes
        sections <- unique(notes$Section)

        for (sec in sections) {
          sec_notes <- notes[notes$Section == sec, , drop = FALSE]
          openxlsx::writeData(wb, "Notes", sec, startRow = r)
          openxlsx::addStyle(wb, "Notes", style_section, rows = r, cols = 1:2, gridExpand = TRUE)
          r <- r + 1

          for (i in seq_len(nrow(sec_notes))) {
            note_text <- escape_text(sec_notes$Note[i])
            openxlsx::writeData(wb, "Notes", paste("-", note_text), startRow = r, startCol = 1)
            r <- r + 1
          }
          r <- r + 1
        }

        openxlsx::setColWidths(wb, "Notes", cols = 1, widths = 80)
      }

      # Add Run_Status sheet if run_state is available
      if (!is.null(run_state) && exists("turas_write_run_status_sheet", mode = "function")) {
        run_result <- if (is.environment(run_state)) {
          turas_run_state_result(run_state)
        } else {
          run_state
        }
        tryCatch(
          turas_write_run_status_sheet(wb, run_result),
          error = function(e) {
            if (verbose) message("  Note: Could not write Run_Status sheet: ", conditionMessage(e))
          }
        )
      }

      # TRS v1.0: Use atomic save to prevent file corruption on network/OneDrive folders
      if (exists("turas_save_workbook_atomic", mode = "function")) {
        save_result <- turas_save_workbook_atomic(wb, output_file, module = "WEIGHTING")
        if (!save_result$success) {
          weighting_refuse(
            code = "IO_ATOMIC_SAVE_FAILED",
            title = "Failed to Save Diagnostics Report",
            problem = sprintf("Atomic save failed for: %s", output_file),
            why_it_matters = "Diagnostics report could not be saved safely.",
            how_to_fix = c(
              "Check directory permissions",
              "Ensure file is not open in another program",
              "Verify disk space is available"
            ),
            details = save_result$error
          )
        }
      } else {
        weighting_refuse(
          code = "IO_ATOMIC_SAVE_UNAVAILABLE",
          title = "Atomic Save Not Available",
          problem = "The turas_save_workbook_atomic function is required but not loaded.",
          why_it_matters = "Direct file saves risk corruption on network/OneDrive-synced folders.",
          how_to_fix = c(
            "Ensure Turas shared library is accessible",
            "Verify modules/shared/lib/turas_save_workbook_atomic.R exists",
            "Contact support if the problem persists"
          )
        )
      }

    } else {
      weighting_refuse(
        code = "IO_UNSUPPORTED_FORMAT",
        title = "Unsupported Diagnostics Format",
        problem = sprintf("Cannot write diagnostics to format: .%s", file_ext),
        why_it_matters = "Diagnostics report cannot be saved in unsupported formats.",
        how_to_fix = c(
          "Use a supported format: .txt or .xlsx",
          "Change the diagnostics_file extension in your config"
        )
      )
    }

    if (verbose) {
      message("  Report saved to: ", output_file)
    }

    return(invisible(output_file))

  }, turas_refusal = function(e) {
    # Re-signal TRS refusals with their original code (don't wrap in generic IO error)
    stop(e)
  }, error = function(e) {
    weighting_refuse(
      code = "IO_DIAGNOSTICS_WRITE_FAILED",
      title = "Failed to Write Diagnostics File",
      problem = sprintf("Could not write diagnostics report to: %s", output_file),
      why_it_matters = "Weighting completed but diagnostics could not be saved.",
      how_to_fix = c(
        "Check directory permissions",
        "Ensure file is not open in another program",
        "Verify disk space is available"
      ),
      details = conditionMessage(e)
    )
  })
}

#' Print Run Summary
#'
#' Prints a summary of the weighting run to console.
#'
#' @param weighting_results List, results from run_weighting
#' @export
print_run_summary <- function(weighting_results) {
  cat("\n")
  cat(strrep("=", 80), "\n")
  cat("WEIGHTING RUN COMPLETE\n")
  cat(strrep("=", 80), "\n")

  cat("\nProject: ", weighting_results$config$general$project_name, "\n")
  cat("Records: ", nrow(weighting_results$data), "\n")
  cat("Weights created: ", length(weighting_results$weight_names), "\n")

  cat("\nWeight Summary:\n")
  cat(strrep("-", 70), "\n")
  cat(sprintf("%-25s %-10s %12s %12s %10s\n",
              "Weight Name", "Method", "Effective N", "Design Eff.", "Status"))
  cat(strrep("-", 70), "\n")

  for (weight_name in weighting_results$weight_names) {
    result <- weighting_results$weight_results[[weight_name]]
    spec <- weighting_results$config$weight_specifications
    method <- spec$method[spec$weight_name == weight_name]

    if (!is.null(result$diagnostics)) {
      diag <- result$diagnostics
      status <- diag$quality$status
      eff_n <- diag$effective_sample$effective_n
      deff <- diag$effective_sample$design_effect
    } else {
      status <- "N/A"
      eff_n <- NA
      deff <- NA
    }

    cat(sprintf("%-25s %-10s %12s %12s %10s\n",
                weight_name,
                method,
                if (is.na(eff_n)) "N/A" else format(eff_n, big.mark = ","),
                if (is.na(deff)) "N/A" else sprintf("%.2f", deff),
                status))
  }

  cat(strrep("-", 70), "\n")

  # Output files
  if (!is.null(weighting_results$output_file)) {
    cat("\nOutput files:\n")
    cat("  Data: ", weighting_results$output_file, "\n")
  }

  if (!is.null(weighting_results$diagnostics_file)) {
    cat("  Diagnostics: ", weighting_results$diagnostics_file, "\n")
  }

  cat("\n")
}

#' Create Weight Summary Data Frame
#'
#' Creates a data frame summarizing all calculated weights.
#'
#' @param weighting_results List, results from run_weighting
#' @return Data frame with weight summaries
#' @export
create_weight_summary_df <- function(weighting_results) {
  summary_df <- data.frame(
    weight_name = character(0),
    method = character(0),
    n_total = integer(0),
    n_valid = integer(0),
    min = numeric(0),
    max = numeric(0),
    mean = numeric(0),
    cv = numeric(0),
    effective_n = integer(0),
    design_effect = numeric(0),
    efficiency = numeric(0),
    quality_status = character(0),
    stringsAsFactors = FALSE
  )

  for (weight_name in weighting_results$weight_names) {
    result <- weighting_results$weight_results[[weight_name]]
    spec <- weighting_results$config$weight_specifications
    method <- spec$method[spec$weight_name == weight_name]

    if (!is.null(result$diagnostics)) {
      diag <- result$diagnostics

      summary_df <- rbind(summary_df, data.frame(
        weight_name = weight_name,
        method = method,
        n_total = diag$sample_size$n_total,
        n_valid = diag$sample_size$n_valid,
        min = diag$distribution$min,
        max = diag$distribution$max,
        mean = diag$distribution$mean,
        cv = diag$distribution$cv,
        effective_n = diag$effective_sample$effective_n,
        design_effect = diag$effective_sample$design_effect,
        efficiency = diag$effective_sample$efficiency,
        quality_status = diag$quality$status,
        stringsAsFactors = FALSE
      ))
    }
  }

  return(summary_df)
}
