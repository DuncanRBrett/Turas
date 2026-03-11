# ==============================================================================
# SEGMENTATION EXCEL EXPORT
# ==============================================================================
# Export segment assignments and reports to Excel
# Part of Turas Segmentation Module
# ==============================================================================

# Source config utilities for label formatting

#' Create Segment Output Styles
#'
#' Creates a reusable style list for professional Excel output,
#' matching the catdriver module's formatting standard.
#'
#' @param wb openxlsx Workbook object
#' @return List of style objects
#' @keywords internal
create_segment_output_styles <- function(wb) {
  list(
    header = openxlsx::createStyle(
      fontColour = "#FFFFFF",
      fgFill = "#4472C4",
      halign = "center",
      valign = "center",
      textDecoration = "bold",
      border = "TopBottomLeftRight",
      borderColour = "#2F5496"
    ),
    subheader = openxlsx::createStyle(
      fgFill = "#D6DCE4",
      halign = "left",
      textDecoration = "bold",
      border = "TopBottomLeftRight"
    ),
    title = openxlsx::createStyle(
      fontSize = 16,
      textDecoration = "bold",
      halign = "left"
    ),
    section = openxlsx::createStyle(
      fontSize = 12,
      textDecoration = "bold",
      halign = "left",
      border = "bottom",
      borderColour = "#4472C4"
    ),
    normal = openxlsx::createStyle(
      halign = "left",
      valign = "center"
    ),
    number = openxlsx::createStyle(
      halign = "right",
      numFmt = "0.000"
    ),
    success = openxlsx::createStyle(
      fgFill = "#C6EFCE",
      halign = "left"
    ),
    warning = openxlsx::createStyle(
      fgFill = "#FFF2CC",
      halign = "left"
    ),
    error = openxlsx::createStyle(
      fgFill = "#FFC7CE",
      halign = "left"
    )
  )
}


#' Add Run_Status Sheet (TRS v1.0)
#'
#' Creates the required Run_Status sheet per TRS v1.0 spec with
#' professional formatting. This sheet is always placed FIRST in the
#' workbook for governance compliance.
#'
#' @param wb openxlsx Workbook object
#' @param run_status Character, "PASS" | "PARTIAL" | "REFUSED"
#' @param degraded Logical, whether output is degraded
#' @param degraded_reasons Character vector, reasons for degradation
#' @param affected_outputs Character vector, which outputs are affected
#' @param guard_summary Guard summary list (optional, for additional details)
#' @param styles Style list from create_segment_output_styles()
#' @keywords internal
add_segment_run_status_sheet <- function(wb, run_status = "PASS",
                                          degraded = FALSE,
                                          degraded_reasons = character(0),
                                          affected_outputs = character(0),
                                          guard_summary = NULL,
                                          styles = NULL) {

  openxlsx::addWorksheet(wb, "Run_Status")

  if (is.null(styles)) {
    styles <- create_segment_output_styles(wb)
  }

  row <- 1

  # Title
  openxlsx::writeData(wb, "Run_Status", "SEGMENT RUN STATUS", startRow = row, startCol = 1)
  openxlsx::addStyle(wb, "Run_Status", styles$title, rows = row, cols = 1)
  row <- row + 2

  # Status row
  openxlsx::writeData(wb, "Run_Status", "run_status:", startRow = row, startCol = 1)
  openxlsx::writeData(wb, "Run_Status", run_status, startRow = row, startCol = 2)
  if (run_status == "PASS") {
    openxlsx::addStyle(wb, "Run_Status", styles$success, rows = row, cols = 2)
  } else if (run_status == "PARTIAL") {
    openxlsx::addStyle(wb, "Run_Status", styles$warning, rows = row, cols = 2)
  } else if (run_status == "REFUSED") {
    openxlsx::addStyle(wb, "Run_Status", styles$error, rows = row, cols = 2)
  }
  row <- row + 1

  # Degraded flag
  openxlsx::writeData(wb, "Run_Status", "degraded:", startRow = row, startCol = 1)
  openxlsx::writeData(wb, "Run_Status", if (degraded) "TRUE" else "FALSE", startRow = row, startCol = 2)
  row <- row + 1

  # Module
  openxlsx::writeData(wb, "Run_Status", "module:", startRow = row, startCol = 1)
  openxlsx::writeData(wb, "Run_Status", paste0("SEGMENT v", SEGMENT_VERSION),
                       startRow = row, startCol = 2)
  row <- row + 1

  # Timestamp
  openxlsx::writeData(wb, "Run_Status", "timestamp:", startRow = row, startCol = 1)
  openxlsx::writeData(wb, "Run_Status", format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                       startRow = row, startCol = 2)
  row <- row + 2

  # Degraded reasons (if any)
  if (length(degraded_reasons) > 0) {
    openxlsx::writeData(wb, "Run_Status", "DEGRADED REASONS:", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Run_Status", styles$section, rows = row, cols = 1)
    row <- row + 1

    for (reason in degraded_reasons) {
      openxlsx::writeData(wb, "Run_Status", paste0("- ", reason), startRow = row, startCol = 1)
      row <- row + 1
    }
    row <- row + 1
  }

  # Affected outputs (if any)
  if (length(affected_outputs) > 0) {
    openxlsx::writeData(wb, "Run_Status", "AFFECTED OUTPUTS:", startRow = row, startCol = 1)
    openxlsx::addStyle(wb, "Run_Status", styles$section, rows = row, cols = 1)
    row <- row + 1

    for (output in affected_outputs) {
      openxlsx::writeData(wb, "Run_Status", paste0("- ", output), startRow = row, startCol = 1)
      row <- row + 1
    }
    row <- row + 1
  }

  # Guard summary details (if available)
  if (!is.null(guard_summary)) {
    if (length(guard_summary$warnings) > 0) {
      openxlsx::writeData(wb, "Run_Status", "WARNINGS:", startRow = row, startCol = 1)
      openxlsx::addStyle(wb, "Run_Status", styles$section, rows = row, cols = 1)
      row <- row + 1

      for (w in guard_summary$warnings) {
        openxlsx::writeData(wb, "Run_Status", paste0("- ", w), startRow = row, startCol = 1)
        row <- row + 1
      }
      row <- row + 1
    }

    if (length(guard_summary$stability_flags) > 0) {
      openxlsx::writeData(wb, "Run_Status", "STABILITY FLAGS:", startRow = row, startCol = 1)
      openxlsx::addStyle(wb, "Run_Status", styles$section, rows = row, cols = 1)
      row <- row + 1

      for (flag in guard_summary$stability_flags) {
        openxlsx::writeData(wb, "Run_Status", paste0("- ", flag), startRow = row, startCol = 1)
        row <- row + 1
      }
    }
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Run_Status", cols = 1, widths = 25)
  openxlsx::setColWidths(wb, "Run_Status", cols = 2, widths = 60)
}


#' Write Sheets to openxlsx Workbook
#'
#' Helper to write a named list of data frames as sheets in an openxlsx
#' workbook with header styling.
#'
#' @param wb openxlsx Workbook object
#' @param sheets Named list of data frames
#' @param styles Style list from create_segment_output_styles()
#' @keywords internal
write_sheets_to_workbook <- function(wb, sheets, styles) {
  for (sheet_name in names(sheets)) {
    df <- sheets[[sheet_name]]
    if (is.null(df) || (is.data.frame(df) && nrow(df) == 0)) next

    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet_name, df, headerStyle = styles$header)

    # Set reasonable column widths
    n_cols <- ncol(df)
    widths <- pmin(pmax(nchar(names(df)) * 1.2 + 2, 12), 40)
    openxlsx::setColWidths(wb, sheet_name, cols = seq_len(n_cols), widths = widths)
  }
}


#' Save Workbook with Atomic Safety
#'
#' Saves an openxlsx workbook using the atomic save pattern if available,
#' falling back to direct save.
#'
#' @param wb openxlsx Workbook object
#' @param output_path Character, output file path
#' @keywords internal
save_workbook_safe <- function(wb, output_path) {
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, module = "SEGMENT")
    if (!save_result$success) {
      cat(sprintf("  [SEGMENT] Failed to save workbook: %s\n", save_result$error))
    }
  } else {
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  }
}

#' Null coalesce operator
#' @keywords internal
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

#' Export segment assignments file
#'
#' DESIGN: Simple join table (respondent_id, segment, segment_name, outlier_flag)
#' PURPOSE: Easy to merge back with original data for cross-module analysis
#'
#' @param data Original data frame
#' @param clusters Integer vector, cluster assignments
#' @param segment_names Character vector, segment names
#' @param id_var Character, ID variable name
#' @param output_path Character, output file path
#' @param outlier_flags Logical vector, outlier flags (optional)
#' @param probabilities Matrix of membership probabilities (GMM only, optional)
#' @export
export_segment_assignments <- function(data, clusters, segment_names, id_var, output_path,
                                      outlier_flags = NULL, probabilities = NULL) {
  cat(sprintf("  Exporting segment assignments: %s\n", basename(output_path)))

  # Create assignments data frame
  assignments <- data.frame(
    respondent_id = data[[id_var]],
    segment_id = clusters,
    segment_name = segment_names[clusters],
    stringsAsFactors = FALSE
  )

  # Add outlier flags if provided
  if (!is.null(outlier_flags) && length(outlier_flags) > 0) {
    assignments$outlier_flag <- outlier_flags
  }

  # Add GMM membership probabilities if provided
  if (!is.null(probabilities) && is.matrix(probabilities)) {
    prob_df <- as.data.frame(probabilities)
    names(prob_df) <- paste0("prob_", segment_names[seq_len(ncol(probabilities))])
    assignments <- cbind(assignments, prob_df)
    assignments$max_probability <- apply(probabilities, 1, max)
    assignments$uncertainty <- 1 - assignments$max_probability
  }

  # Rename first column to match original ID variable name
  names(assignments)[1] <- id_var

  # Build Segment_Names sheet for user editing
  unique_ids <- sort(unique(clusters))
  names_df <- data.frame(
    Segment_ID = unique_ids,
    Suggested_Name = segment_names[unique_ids],
    Custom_Name = rep("", length(unique_ids)),
    stringsAsFactors = FALSE
  )

  sheets <- list(
    Segment_Assignments = assignments,
    Segment_Names = names_df
  )

  segment_write_xlsx(sheets, output_path, "segment assignments")

  cat(sprintf("  Exported %d segment assignments (with Segment_Names sheet)\n", nrow(assignments)))

  return(invisible(output_path))
}

#' Read edited segment names from an assignments Excel file
#'
#' Reads the Segment_Names sheet from a segment assignments Excel file.
#' Uses Custom_Name if filled in by the user, otherwise falls back to
#' Suggested_Name, then to generic "Segment {i}" names.
#'
#' @param file_path Character, path to the segment assignments Excel file
#' @param k Integer, expected number of segments (optional, used for validation)
#' @return Character vector of segment names, or NULL on failure
#' @export
read_segment_names_from_file <- function(file_path, k = NULL) {
  if (is.null(file_path) || !nzchar(file_path)) {
    return(NULL)
  }

  if (!file.exists(file_path)) {
    cat(sprintf("  [WARNING] Segment names file not found: %s\n", file_path))
    return(NULL)
  }

  # Read Segment_Names sheet
  names_df <- tryCatch({
    openxlsx::read.xlsx(file_path, sheet = "Segment_Names")
  }, error = function(e) {
    cat(sprintf("  [WARNING] Could not read Segment_Names sheet: %s\n", e$message))
    NULL
  })

  if (is.null(names_df) || nrow(names_df) == 0) {
    cat("  [WARNING] Segment_Names sheet is empty or missing\n")
    return(NULL)
  }

  # Build names: prefer Custom_Name > Suggested_Name > "Segment {i}"
  n <- nrow(names_df)
  names_out <- character(n)
  for (i in seq_len(n)) {
    custom <- if ("Custom_Name" %in% names(names_df)) names_df$Custom_Name[i] else NA
    suggested <- if ("Suggested_Name" %in% names(names_df)) names_df$Suggested_Name[i] else NA

    if (!is.na(custom) && nzchar(trimws(custom))) {
      names_out[i] <- trimws(custom)
    } else if (!is.na(suggested) && nzchar(trimws(suggested))) {
      names_out[i] <- trimws(suggested)
    } else {
      names_out[i] <- paste0("Segment ", i)
    }
  }

  # Validate against expected k if provided
  if (!is.null(k) && length(names_out) != k) {
    cat(sprintf("  [WARNING] Segment_Names has %d rows but expected %d segments\n",
                length(names_out), k))
    return(NULL)
  }

  cat(sprintf("  Loaded %d segment names from: %s\n", length(names_out), basename(file_path)))
  return(names_out)
}

#' Export exploration mode k selection report
#'
#' DESIGN: Multi-tab Excel with metrics comparison and profiles
#' TABS: Metrics_Comparison, Profile_K3, Profile_K4, etc., Run_Status
#'
#' @param exploration_result Result from run_kmeans_exploration()
#' @param metrics_result Result from calculate_exploration_metrics()
#' @param recommendation Result from recommend_k()
#' @param output_path Character, output file path
#' @param run_result TRS run result object (optional)
#' @export
export_exploration_report <- function(exploration_result, metrics_result,
                                      recommendation, output_path, run_result = NULL) {
  cat(sprintf("Exporting exploration report to: %s\n", basename(output_path)))

  data_list <- exploration_result$data_list
  config <- data_list$config
  k_range <- exploration_result$k_range

  # Prepare metrics comparison sheet
  metrics_df <- metrics_result$metrics_df

  # Add recommendation column
  metrics_df$Recommendation <- ""
  rec_idx <- which(metrics_df$k == recommendation$recommended_k)
  if (length(rec_idx) > 0) {
    # Get silhouette from metrics_df
    rec_silhouette <- metrics_df$avg_silhouette_width[rec_idx]
    metrics_df$Recommendation[rec_idx] <- sprintf("← Best silhouette (%.3f)", rec_silhouette)
  }
  
  # Check for warnings
  for (i in 1:nrow(metrics_df)) {
    if (metrics_df$min_segment_pct[i] < config$min_segment_size_pct) {
      if (nchar(metrics_df$Recommendation[i]) > 0) {
        metrics_df$Recommendation[i] <- paste(metrics_df$Recommendation[i],
                                              "⚠ Small segment")
      } else {
        metrics_df$Recommendation[i] <- "⚠ Small segment"
      }
    }
  }
  
  # Round numeric columns for readability
  metrics_df$avg_silhouette_width <- round(metrics_df$avg_silhouette_width, 3)
  metrics_df$tot.withinss <- round(metrics_df$tot.withinss, 1)
  metrics_df$betweenss_totss <- round(metrics_df$betweenss_totss, 3)
  metrics_df$min_segment_pct <- round(metrics_df$min_segment_pct, 1)
  
  # Prepare profiles for each k
  profile_sheets <- list()
  profile_sheets[["Metrics_Comparison"]] <- metrics_df

  for (k in k_range) {
    cat(sprintf("  Creating profile for k=%d...\n", k))

    result_k <- exploration_result$results[[as.character(k)]]
    if (is.null(result_k)) next
    clusters <- result_k$clusters

    # Create profile
    profile <- create_full_segment_profile(
      data = data_list$data,
      clusters = clusters,
      clustering_vars = config$clustering_vars,
      profile_vars = config$profile_vars
    )

    # Format profile for export
    profile_export <- profile$clustering_profile

    # Apply question labels to Variable column if available
    if (!is.null(config$question_labels)) {
      profile_export$Variable <- format_variable_label(profile_export$Variable,
                                                       config$question_labels)
    }

    # Round numeric columns
    num_cols <- sapply(profile_export, is.numeric)
    profile_export[num_cols] <- lapply(profile_export[num_cols], function(x) round(x, 2))

    # Add segment sizes as last rows
    size_row <- data.frame(
      Variable = "Segment_size_n",
      stringsAsFactors = FALSE
    )
    pct_row <- data.frame(
      Variable = "Segment_size_pct",
      stringsAsFactors = FALSE
    )

    for (col in names(profile_export)[-1]) {  # Skip Variable column
      size_row[[col]] <- NA
      pct_row[[col]] <- NA
    }

    # Set segment size values
    seg_sizes <- profile$segment_sizes
    for (i in 1:nrow(seg_sizes)) {
      seg_col <- paste0("Segment_", seg_sizes$Segment[i])
      if (seg_col %in% names(size_row)) {
        size_row[[seg_col]] <- seg_sizes$Count[i]
        pct_row[[seg_col]] <- round(seg_sizes$Percentage[i], 1)
      }
    }

    # Set overall size
    size_row$Overall <- nrow(data_list$data)
    pct_row$Overall <- 100.0

    profile_export <- rbind(profile_export, size_row, pct_row)

    # Store with sheet name
    sheet_name <- sprintf("Profile_K%d", k)
    profile_sheets[[sheet_name]] <- profile_export
  }

  # Add Variable_Contribution sheet for recommended k
  cat("  Creating variable contribution sheet...\n")
  rec_k <- recommendation$recommended_k
  rec_k_result <- exploration_result$results[[as.character(rec_k)]]

  if (!is.null(rec_k_result) && exists("rank_variable_importance", mode = "function")) {
    var_importance <- tryCatch({
      suppressMessages(capture.output(
        result <- rank_variable_importance(
          data = data_list$data,
          clusters = rec_k_result$clusters,
          clustering_vars = config$clustering_vars,
          question_labels = config$question_labels
        ),
        type = "output"
      ))
      result
    }, error = function(e) {
      cat(sprintf("  [WARNING] Variable contribution analysis failed: %s\n", e$message))
      NULL
    })

    if (!is.null(var_importance) && !is.null(var_importance$ranking)) {
      contrib_df <- var_importance$ranking
      contrib_df$Annotation <- ifelse(
        contrib_df$Category == "MINIMAL IMPACT",
        "<- Consider removing",
        ""
      )
      profile_sheets[["Variable_Contribution"]] <- contrib_df
      cat(sprintf("  Variable contribution: %d ESSENTIAL, %d USEFUL, %d MINIMAL IMPACT\n",
                  length(var_importance$essential_vars),
                  length(var_importance$useful_vars),
                  length(var_importance$drop_candidates)))
    }
  }

  # Add outlier analysis sheet if outliers were detected
  if (config$outlier_detection && !is.null(data_list$outlier_result)) {
    cat("  Creating outlier analysis sheet...\n")

    outlier_report <- create_outlier_report(
      outlier_result = data_list$outlier_result,
      data = data_list$data,
      id_var = config$id_variable,
      standardized_data = as.data.frame(data_list$scaled_data),
      clustering_vars = config$clustering_vars
    )

    if (nrow(outlier_report) > 0) {
      profile_sheets[["Outliers"]] <- outlier_report
    }
  }

  # Add variable selection sheets if variable selection was performed
  if (config$variable_selection && !is.null(data_list$variable_selection_result)) {
    cat("  Creating variable selection sheets...\n")

    varsel <- data_list$variable_selection_result

    # Selected variables sheet with labels
    selected_df <- data.frame(
      Variable = varsel$selected_vars,
      Status = "Selected",
      stringsAsFactors = FALSE
    )

    # Add labels column if available
    if (!is.null(config$question_labels)) {
      selected_df$Label <- sapply(varsel$selected_vars, function(v) {
        if (v %in% names(config$question_labels)) {
          config$question_labels[v]
        } else {
          ""
        }
      }, USE.NAMES = FALSE)
    }

    profile_sheets[["VarSel_Selected"]] <- selected_df

    # Variable statistics sheet with labels
    if (!is.null(varsel$selection_log$variance)) {
      var_stats <- varsel$selection_log$variance$variance_df
      var_stats$selected <- var_stats$variable %in% varsel$selected_vars
      var_stats$variance <- round(var_stats$variance, 4)
      var_stats$sd <- round(var_stats$sd, 4)

      # Add labels column if available
      if (!is.null(config$question_labels)) {
        var_stats$label <- sapply(var_stats$variable, function(v) {
          if (v %in% names(config$question_labels)) {
            config$question_labels[v]
          } else {
            ""
          }
        }, USE.NAMES = FALSE)
        # Reorder columns to put label after variable
        var_stats <- var_stats[, c("variable", "label", setdiff(names(var_stats), c("variable", "label")))]
      }

      profile_sheets[["VarSel_Statistics"]] <- var_stats
    }
  }

  # Write to Excel using openxlsx for professional formatting
  wb <- openxlsx::createWorkbook()
  styles <- create_segment_output_styles(wb)

  # TRS v1.0: Run_Status sheet FIRST
  run_status_val <- if (!is.null(run_result)) (run_result$status %||% "PASS") else "PASS"
  add_segment_run_status_sheet(wb,
    run_status = run_status_val,
    degraded = !identical(run_status_val, "PASS"),
    styles = styles
  )

  # Write data sheets
  write_sheets_to_workbook(wb, profile_sheets, styles)

  # Save
  save_workbook_safe(wb, output_path)

  cat(sprintf("  Exported exploration report with %d sheets\n", length(profile_sheets) + 1))

  return(invisible(output_path))
}

#' Export final segmentation report
#'
#' DESIGN: Comprehensive multi-tab report for final solution
#' TABS: Summary, Segment_Profiles, Validation, Executive_Summary,
#'       Classification_Rules, GMM_Membership, Run_Status
#'
#' @param final_result Standard clustering result list
#' @param profile_result Result from create_full_segment_profile()
#' @param validation_metrics Validation metrics list
#' @param output_path Character, output file path
#' @param run_result TRS run result object (optional)
#' @param enhanced List of enhanced features (rules, cards, stability)
#' @param segment_names Character vector of segment names
#' @param exec_summary Executive summary list (optional)
#' @param gmm_membership GMM membership summary (optional)
#' @param run_status_details List with degraded_reasons and affected_outputs (optional)
#' @param guard_summary Guard summary list for Run_Status sheet (optional)
#' @export
export_final_report <- function(final_result, profile_result, validation_metrics,
                                 output_path, run_result = NULL,
                                 enhanced = list(), segment_names = NULL,
                                 exec_summary = NULL, gmm_membership = NULL,
                                 run_status_details = NULL,
                                 guard_summary = NULL) {
  cat(sprintf("  Exporting segmentation report: %s\n", basename(output_path)))

  data_list <- final_result$data_list
  config <- data_list$config
  k <- final_result$k
  model <- final_result$model

  # Prepare all sheets
  sheets <- list()

  # ===========================================================================
  # SHEET 1: Summary
  # ===========================================================================

  # Format clustering variables with labels
  clustering_vars_display <- if (!is.null(config$question_labels)) {
    paste(format_variable_label(config$clustering_vars, config$question_labels), collapse = ", ")
  } else {
    paste(config$clustering_vars, collapse = ", ")
  }

  summary_text <- c(
    "SEGMENTATION SUMMARY",
    "====================",
    "",
    sprintf("Project: %s", config$project_name),
    sprintf("Date: %s", Sys.Date()),
    sprintf("Analyst: %s", config$analyst_name),
    "",
    "DATA OVERVIEW",
    "-------------",
    sprintf("Total respondents: %d", data_list$n_original),
    sprintf("Valid responses: %d", nrow(data_list$data)),
    sprintf("Clustering variables: %s", clustering_vars_display),
    sprintf("Number of segments: %d", k)
  )

  # Add variable selection information if enabled
  if (config$variable_selection && !is.null(data_list$variable_selection_result)) {
    varsel <- data_list$variable_selection_result

    # Format selected variables with labels
    selected_vars_display <- if (!is.null(config$question_labels)) {
      paste(format_variable_label(varsel$selected_vars, config$question_labels), collapse = ", ")
    } else {
      paste(varsel$selected_vars, collapse = ", ")
    }

    summary_text <- c(
      summary_text,
      "",
      "VARIABLE SELECTION",
      "------------------",
      sprintf("Method: %s", varsel$method),
      sprintf("Original variables: %d", varsel$n_original),
      sprintf("Selected variables: %d", varsel$n_selected),
      sprintf("Selected: %s", selected_vars_display)
    )
  }

  # Add outlier information if enabled
  if (config$outlier_detection && !is.null(data_list$outlier_handling)) {
    summary_text <- c(
      summary_text,
      "",
      "OUTLIER DETECTION",
      "-----------------",
      sprintf("Method: %s", config$outlier_method),
      sprintf("Outliers detected: %d (%.1f%%)",
              data_list$outlier_handling$n_outliers,
              data_list$outlier_handling$pct_outliers),
      sprintf("Handling strategy: %s", config$outlier_handling)
    )
  }

  summary_text <- c(
    summary_text,
    "",
    "SEGMENTATION QUALITY",
    "--------------------",
    sprintf("Method: %s clustering", toupper(final_result$method %||% "kmeans")),
    sprintf("Average silhouette: %.3f", validation_metrics$avg_silhouette),
    sprintf("Between/Total SS ratio: %.3f", validation_metrics$betweenss_totss),
    "",
    "SEGMENTS IDENTIFIED",
    "-------------------"
  )

  # Add segment summaries
  for (i in 1:k) {
    seg_name <- if (is.character(config$segment_names) && length(config$segment_names) >= i) {
      config$segment_names[i]
    } else {
      paste0("Segment ", i)
    }

    summary_text <- c(
      summary_text,
      "",
      sprintf("Segment %d: %s (%.1f%%, n=%d)",
              i, seg_name,
              profile_result$segment_sizes$Percentage[i],
              profile_result$segment_sizes$Count[i])
    )
  }

  sheets[["Summary"]] <- data.frame(Content = summary_text, stringsAsFactors = FALSE)

  # ===========================================================================
  # SHEET 2: Segment Profiles
  # ===========================================================================

  profile_export <- profile_result$clustering_profile

  # Apply question labels to Variable column if available
  if (!is.null(config$question_labels)) {
    profile_export$Variable <- format_variable_label(profile_export$Variable,
                                                     config$question_labels)
  }

  # Round numeric columns
  num_cols <- sapply(profile_export, is.numeric)
  profile_export[num_cols] <- lapply(profile_export[num_cols], function(x) round(x, 2))

  # Add segment sizes
  size_row <- data.frame(Variable = "Segment_size_n", stringsAsFactors = FALSE)
  pct_row <- data.frame(Variable = "Segment_size_pct", stringsAsFactors = FALSE)

  for (col in names(profile_export)[-1]) {
    size_row[[col]] <- NA
    pct_row[[col]] <- NA
  }

  for (i in 1:k) {
    seg_col <- paste0("Segment_", i)
    if (seg_col %in% names(size_row)) {
      size_row[[seg_col]] <- profile_result$segment_sizes$Count[i]
      pct_row[[seg_col]] <- round(profile_result$segment_sizes$Percentage[i], 1)
    }
  }

  size_row$Overall <- nrow(data_list$data)
  pct_row$Overall <- 100.0

  profile_export <- rbind(profile_export, size_row, pct_row)

  sheets[["Segment_Profiles"]] <- profile_export

  # ===========================================================================
  # SHEET 3: Validation Metrics
  # ===========================================================================

  validation_df <- data.frame(
    Metric = c(
      "Average Silhouette",
      "Total Within-cluster SS",
      "Total Between-cluster SS",
      "Between/Total SS ratio"
    ),
    Value = c(
      round(validation_metrics$avg_silhouette, 3),
      round(validation_metrics$tot_withinss, 1),
      round(validation_metrics$betweenss, 1),
      round(validation_metrics$betweenss_totss, 3)
    ),
    stringsAsFactors = FALSE
  )

  sheets[["Validation"]] <- validation_df

  # ===========================================================================
  # SHEET 4 (optional): Outlier Analysis
  # ===========================================================================

  if (config$outlier_detection && !is.null(data_list$outlier_result)) {
    outlier_report <- create_outlier_report(
      outlier_result = data_list$outlier_result,
      data = data_list$data,
      id_var = config$id_variable,
      standardized_data = as.data.frame(data_list$scaled_data),
      clustering_vars = config$clustering_vars
    )

    if (nrow(outlier_report) > 0) {
      sheets[["Outliers"]] <- outlier_report
    }
  }

  # ===========================================================================
  # SHEET 5 (optional): Variable Selection
  # ===========================================================================

  if (config$variable_selection && !is.null(data_list$variable_selection_result)) {
    varsel <- data_list$variable_selection_result

    # Selected variables sheet with labels
    selected_df <- data.frame(
      Variable = varsel$selected_vars,
      Status = "Selected",
      stringsAsFactors = FALSE
    )

    # Add labels column if available
    if (!is.null(config$question_labels)) {
      selected_df$Label <- sapply(varsel$selected_vars, function(v) {
        if (v %in% names(config$question_labels)) {
          config$question_labels[v]
        } else {
          ""
        }
      }, USE.NAMES = FALSE)
    }

    sheets[["VarSel_Selected"]] <- selected_df

    # Variable statistics sheet with labels
    if (!is.null(varsel$selection_log$variance)) {
      var_stats <- varsel$selection_log$variance$variance_df
      var_stats$selected <- var_stats$variable %in% varsel$selected_vars
      var_stats$variance <- round(var_stats$variance, 4)
      var_stats$sd <- round(var_stats$sd, 4)

      # Add labels column if available
      if (!is.null(config$question_labels)) {
        var_stats$label <- sapply(var_stats$variable, function(v) {
          if (v %in% names(config$question_labels)) {
            config$question_labels[v]
          } else {
            ""
          }
        }, USE.NAMES = FALSE)
        # Reorder columns to put label after variable
        var_stats <- var_stats[, c("variable", "label", setdiff(names(var_stats), c("variable", "label")))]
      }

      sheets[["VarSel_Statistics"]] <- var_stats
    }
  }

  # ===========================================================================
  # SHEET: Executive Summary (optional)
  # ===========================================================================

  if (!is.null(exec_summary) && is.list(exec_summary)) {
    exec_lines <- character(0)
    exec_lines <- c(exec_lines, exec_summary$headline %||% "")
    exec_lines <- c(exec_lines, "")
    exec_lines <- c(exec_lines, "KEY FINDINGS:")
    for (f in exec_summary$key_findings) exec_lines <- c(exec_lines, paste0("  - ", f))
    exec_lines <- c(exec_lines, "")
    exec_lines <- c(exec_lines, "QUALITY:")
    exec_lines <- c(exec_lines, paste0("  ", exec_summary$quality_assessment %||% ""))
    if (length(exec_summary$segment_descriptions) > 0) {
      exec_lines <- c(exec_lines, "")
      exec_lines <- c(exec_lines, "SEGMENTS:")
      for (d in exec_summary$segment_descriptions) exec_lines <- c(exec_lines, paste0("  ", d))
    }
    if (length(exec_summary$warnings) > 0) {
      exec_lines <- c(exec_lines, "")
      exec_lines <- c(exec_lines, "WARNINGS:")
      for (w in exec_summary$warnings) exec_lines <- c(exec_lines, paste0("  ! ", w))
    }
    exec_lines <- c(exec_lines, "")
    exec_lines <- c(exec_lines, "RECOMMENDATIONS:")
    for (i in seq_along(exec_summary$recommendations)) {
      exec_lines <- c(exec_lines, sprintf("  %d. %s", i, exec_summary$recommendations[i]))
    }

    sheets[["Executive_Summary"]] <- data.frame(Content = exec_lines, stringsAsFactors = FALSE)
  }

  # ===========================================================================
  # SHEET: Classification Rules (optional)
  # ===========================================================================

  if (!is.null(enhanced$rules) && is.list(enhanced$rules)) {
    if (!is.null(enhanced$rules$rules_df)) {
      sheets[["Classification_Rules"]] <- enhanced$rules$rules_df
    } else if (!is.null(enhanced$rules$rules_text)) {
      sheets[["Classification_Rules"]] <- data.frame(
        Rule = enhanced$rules$rules_text, stringsAsFactors = FALSE
      )
    }
  }

  # ===========================================================================
  # SHEET: GMM Membership (optional)
  # ===========================================================================

  if (!is.null(gmm_membership) && is.list(gmm_membership)) {
    if (!is.null(gmm_membership$summary_df)) {
      sheets[["GMM_Membership"]] <- gmm_membership$summary_df
    }
  }

  # Write to Excel using openxlsx for professional formatting
  wb <- openxlsx::createWorkbook()
  styles <- create_segment_output_styles(wb)

  # TRS v1.0: Run_Status sheet FIRST
  run_status_val <- if (!is.null(run_result)) (run_result$status %||% "PASS") else "PASS"
  degraded <- !identical(run_status_val, "PASS")
  deg_reasons <- if (!is.null(run_status_details)) (run_status_details$degraded_reasons %||% character(0)) else character(0)
  aff_outputs <- if (!is.null(run_status_details)) (run_status_details$affected_outputs %||% character(0)) else character(0)

  # Extract events from run_result as additional degraded reasons
  if (!is.null(run_result) && length(run_result$events) > 0) {
    for (e in run_result$events) {
      if (identical(e$level, "WARNING") || identical(e$level, "ERROR")) {
        deg_reasons <- c(deg_reasons,
          sprintf("[%s] %s", e$code %||% "", e$title %||% ""))
      }
    }
    deg_reasons <- unique(deg_reasons)
  }

  add_segment_run_status_sheet(wb,
    run_status = run_status_val,
    degraded = degraded,
    degraded_reasons = deg_reasons,
    affected_outputs = aff_outputs,
    guard_summary = guard_summary,
    styles = styles
  )

  # Write data sheets
  write_sheets_to_workbook(wb, sheets, styles)

  # Save
  save_workbook_safe(wb, output_path)

  cat(sprintf("  Exported report with %d sheets\n", length(sheets) + 1))

  return(invisible(output_path))
}

#' Create output folder with optional date stamping
#'
#' DESIGN: Creates output directory, optionally with date subfolder
#' RETURNS: Final output path to use
#'
#' @param base_folder Character, base output folder
#' @param create_dated_folder Logical, create date subfolder
#' @return Character, final output folder path
#' @export
create_output_folder <- function(base_folder, create_dated_folder = TRUE) {
  if (create_dated_folder) {
    date_str <- format(Sys.Date(), "%Y-%m-%d")
    output_folder <- file.path(base_folder, date_str)
  } else {
    output_folder <- base_folder
  }

  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
    cat(sprintf("Created output folder: %s\n", output_folder))
  }

  return(output_folder)
}
