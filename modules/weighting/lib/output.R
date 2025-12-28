# ==============================================================================
# WEIGHTING MODULE - OUTPUT FUNCTIONS
# ==============================================================================
# Functions for writing weighted data and generating reports
# Part of TURAS Weighting Module v1.0
# ==============================================================================

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
#' @param verbose Logical, print progress
#' @return Invisible path to written file
#' @export
generate_weighting_report <- function(weighting_results, output_file, verbose = TRUE) {

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

      # Summary sheet
      openxlsx::addWorksheet(wb, "Summary")
      summary_text <- paste(report_lines[1:which(report_lines == strrep("-", 80))[2] + 10], collapse = "\n")
      openxlsx::writeData(wb, "Summary", summary_text)

      # Per-weight sheets
      for (weight_name in weighting_results$weight_names) {
        result <- weighting_results$weight_results[[weight_name]]
        sheet_name <- gsub("[^A-Za-z0-9_]", "_", weight_name)  # Clean sheet name
        sheet_name <- substr(sheet_name, 1, 31)  # Excel max sheet name length

        openxlsx::addWorksheet(wb, sheet_name)

        row_num <- 1

        # Weight header
        openxlsx::writeData(wb, sheet_name, weight_name, startCol = 1, startRow = row_num)
        openxlsx::addStyle(wb, sheet_name,
                          style = openxlsx::createStyle(fontSize = 14, textDecoration = "bold"),
                          rows = row_num, cols = 1)
        row_num <- row_num + 2

        # Diagnostics tables
        if (!is.null(result$diagnostics)) {
          diag <- result$diagnostics

          # Sample size
          openxlsx::writeData(wb, sheet_name, "Sample Size", startCol = 1, startRow = row_num)
          row_num <- row_num + 1
          sample_df <- data.frame(
            Metric = c("Total cases", "Valid weights", "Invalid (NA/zero)"),
            Value = c(diag$sample_size$n_total, diag$sample_size$n_valid,
                     diag$sample_size$n_na + diag$sample_size$n_zero)
          )
          openxlsx::writeData(wb, sheet_name, sample_df, startRow = row_num)
          row_num <- row_num + nrow(sample_df) + 2

          # Weight distribution
          openxlsx::writeData(wb, sheet_name, "Weight Distribution", startCol = 1, startRow = row_num)
          row_num <- row_num + 1
          dist_df <- data.frame(
            Statistic = c("Min", "Q1", "Median", "Q3", "Max", "Mean", "SD", "CV"),
            Value = c(diag$distribution$min, diag$distribution$q1, diag$distribution$median,
                     diag$distribution$q3, diag$distribution$max, diag$distribution$mean,
                     diag$distribution$sd, diag$distribution$cv)
          )
          openxlsx::writeData(wb, sheet_name, dist_df, startRow = row_num)
          row_num <- row_num + nrow(dist_df) + 2

          # Effective sample size
          openxlsx::writeData(wb, sheet_name, "Effective Sample Size", startCol = 1, startRow = row_num)
          row_num <- row_num + 1
          eff_df <- data.frame(
            Metric = c("Effective N", "Design effect", "Efficiency"),
            Value = c(diag$effective_sample$effective_n, diag$effective_sample$design_effect,
                     paste0(round(diag$effective_sample$efficiency, 1), "%"))
          )
          openxlsx::writeData(wb, sheet_name, eff_df, startRow = row_num)
          row_num <- row_num + nrow(eff_df) + 2

          # Quality assessment
          openxlsx::writeData(wb, sheet_name, "Quality Assessment", startCol = 1, startRow = row_num)
          row_num <- row_num + 1
          openxlsx::writeData(wb, sheet_name,
                             data.frame(Status = diag$quality$status),
                             startRow = row_num)
          row_num <- row_num + 2
        }

        # Rim margins
        if (!is.null(result$rim_result) && !is.null(result$rim_result$margins)) {
          openxlsx::writeData(wb, sheet_name, "Rim Target Achievement", startCol = 1, startRow = row_num)
          row_num <- row_num + 1
          openxlsx::writeData(wb, sheet_name, result$rim_result$margins, startRow = row_num)
          row_num <- row_num + nrow(result$rim_result$margins) + 2
        }

        # Design stratum details
        if (!is.null(result$design_result) && !is.null(result$design_result$stratum_summary)) {
          openxlsx::writeData(wb, sheet_name, "Stratum Details", startCol = 1, startRow = row_num)
          row_num <- row_num + 1
          openxlsx::writeData(wb, sheet_name, result$design_result$stratum_summary, startRow = row_num)
        }
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
                format(eff_n, big.mark = ","),
                sprintf("%.2f", deff),
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
