# ==============================================================================
# MAXDIFF MODULE - EXCEL OUTPUT GENERATION - TURAS V10.0
# ==============================================================================
# Excel output generation for MaxDiff results
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# OUTPUT SHEETS:
# - SUMMARY: Project metadata and sample sizes
# - ITEM_SCORES: Main results with all scoring methods
# - SEGMENT_SCORES: Segment-level results
# - INDIVIDUAL_UTILS: Individual-level utilities (optional)
# - MODEL_DIAGNOSTICS: Model fit statistics
# - DESIGN_SUMMARY: Design statistics (if DESIGN mode)
#
# DEPENDENCIES:
# - openxlsx
# - utils.R
# ==============================================================================

OUTPUT_VERSION <- "10.0"

# ==============================================================================
# MAIN OUTPUT GENERATOR
# ==============================================================================

#' Generate MaxDiff Excel Output
#'
#' Creates comprehensive Excel output workbook with all results.
#'
#' @param results List. Analysis results from run_maxdiff_analysis
#' @param config List. Configuration object
#' @param verbose Logical. Print progress messages
#' @param run_result List. Optional TRS run result for Run_Status sheet
#'
#' @return Character. Path to output file
#' @export
generate_maxdiff_output <- function(results, config, verbose = TRUE, run_result = NULL) {

  if (verbose) {
    cat("\n")
    log_message("GENERATING EXCEL OUTPUT", "INFO", verbose)
    cat(paste(rep("-", 60), collapse = ""), "\n")
  }

  # Check openxlsx
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required for Excel output", call. = FALSE)
  }

  # Determine output path
  output_folder <- config$project_settings$Output_Folder
  project_name <- config$project_settings$Project_Name

  if (is.null(output_folder) || !nzchar(output_folder)) {
    output_folder <- config$project_root
  }

  # Create output folder if needed
  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }

  output_filename <- sprintf("%s_MaxDiff_Results.xlsx", project_name)
  output_path <- file.path(output_folder, output_filename)

  # Create workbook
  wb <- openxlsx::createWorkbook()

  # Define styles
  styles <- create_output_styles()

  # ============================================================================
  # SUMMARY SHEET
  # ============================================================================

  if (verbose) log_message("Writing SUMMARY sheet...", "INFO", verbose)

  write_summary_sheet(wb, results, config, styles)

  # ============================================================================
  # ITEM_SCORES SHEET
  # ============================================================================

  if (verbose) log_message("Writing ITEM_SCORES sheet...", "INFO", verbose)

  write_item_scores_sheet(wb, results, config, styles)

  # ============================================================================
  # SEGMENT_SCORES SHEET (if applicable)
  # ============================================================================

  if (!is.null(results$segment_results)) {
    if (verbose) log_message("Writing SEGMENT_SCORES sheet...", "INFO", verbose)
    write_segment_scores_sheet(wb, results, config, styles)
  }

  # ============================================================================
  # INDIVIDUAL_UTILS SHEET (if applicable)
  # ============================================================================

  if (config$output_settings$Export_Individual_Utils &&
      !is.null(results$hb_results) &&
      !is.null(results$hb_results$individual_utilities)) {
    if (verbose) log_message("Writing INDIVIDUAL_UTILS sheet...", "INFO", verbose)
    write_individual_utils_sheet(wb, results, config, styles)
  }

  # ============================================================================
  # MODEL_DIAGNOSTICS SHEET
  # ============================================================================

  if (verbose) log_message("Writing MODEL_DIAGNOSTICS sheet...", "INFO", verbose)

  write_diagnostics_sheet(wb, results, config, styles)

  # ============================================================================
  # DESIGN SHEET (if DESIGN mode)
  # ============================================================================

  if (config$mode == "DESIGN" && !is.null(results$design_result)) {
    if (verbose) log_message("Writing DESIGN sheets...", "INFO", verbose)
    write_design_sheets(wb, results, config, styles)
  }

  # ============================================================================
  # TRS RUN_STATUS SHEET (TRS v1.0)
  # ============================================================================

  if (!is.null(run_result)) {
    if (exists("turas_write_run_status_sheet", mode = "function")) {
      if (verbose) log_message("Writing Run_Status sheet...", "INFO", verbose)
      turas_write_run_status_sheet(wb, run_result)
    }
  }

  # ============================================================================
  # SAVE WORKBOOK (TRS v1.0: Use atomic save if available)
  # ============================================================================

  if (verbose) log_message("Saving workbook...", "INFO", verbose)

  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "MAXD")
    if (!save_result$success) {
      stop(sprintf("Failed to save Excel file: %s\nPath: %s", save_result$error, output_path), call. = FALSE)
    }
  } else {
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  }

  if (verbose) {
    log_message(sprintf("Output saved: %s", output_path), "INFO", verbose)
  }

  return(output_path)
}


# ==============================================================================
# STYLE DEFINITIONS
# ==============================================================================

#' Create output styles
#' @keywords internal
create_output_styles <- function() {

  list(
    header = openxlsx::createStyle(
      fontSize = 12,
      fontColour = "white",
      fgFill = "#2c3e50",
      halign = "center",
      valign = "center",
      textDecoration = "bold",
      border = "TopBottomLeftRight",
      borderColour = "#2c3e50"
    ),

    subheader = openxlsx::createStyle(
      fontSize = 11,
      fontColour = "black",
      fgFill = "#ecf0f1",
      halign = "center",
      valign = "center",
      textDecoration = "bold"
    ),

    number_1dp = openxlsx::createStyle(
      numFmt = "0.0",
      halign = "center"
    ),

    number_2dp = openxlsx::createStyle(
      numFmt = "0.00",
      halign = "center"
    ),

    number_3dp = openxlsx::createStyle(
      numFmt = "0.000",
      halign = "center"
    ),

    percent = openxlsx::createStyle(
      numFmt = "0.0",
      halign = "center"
    ),

    integer = openxlsx::createStyle(
      numFmt = "0",
      halign = "center"
    ),

    text_left = openxlsx::createStyle(
      halign = "left",
      valign = "center"
    ),

    text_center = openxlsx::createStyle(
      halign = "center",
      valign = "center"
    ),

    positive = openxlsx::createStyle(
      fontColour = "#27ae60"
    ),

    negative = openxlsx::createStyle(
      fontColour = "#e74c3c"
    )
  )
}


# ==============================================================================
# SUMMARY SHEET
# ==============================================================================

#' Write SUMMARY sheet
#' @keywords internal
write_summary_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "SUMMARY")

  # Project Information
  project_info <- data.frame(
    Setting = c(
      "Project Name",
      "Mode",
      "Module Version",
      "Generated",
      "Seed"
    ),
    Value = c(
      config$project_settings$Project_Name,
      config$mode,
      config$project_settings$Module_Version,
      format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      as.character(config$project_settings$Seed)
    ),
    stringsAsFactors = FALSE
  )

  # Sample Information
  if (!is.null(results$study_summary)) {
    sample_info <- data.frame(
      Metric = c(
        "Total Respondents",
        "Effective N",
        "Design Effect (DEFF)",
        "Number of Items",
        "Tasks per Respondent",
        "Items per Task",
        "Weighted Analysis"
      ),
      Value = c(
        results$study_summary$n_respondents,
        round(results$study_summary$effective_n, 1),
        round(results$study_summary$design_effect, 3),
        results$study_summary$n_items,
        results$study_summary$n_tasks,
        length(grep("^Item\\d+_ID$",
                    names(results$design))),
        ifelse(results$study_summary$weighted, "Yes", "No")
      ),
      stringsAsFactors = FALSE
    )
  } else {
    sample_info <- data.frame(
      Metric = character(),
      Value = character(),
      stringsAsFactors = FALSE
    )
  }

  # Write project info
  openxlsx::writeData(wb, "SUMMARY", "PROJECT INFORMATION", startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "SUMMARY", styles$header, rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::writeData(wb, "SUMMARY", project_info, startRow = 2, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  # Write sample info
  start_row <- nrow(project_info) + 5
  openxlsx::writeData(wb, "SUMMARY", "SAMPLE INFORMATION", startRow = start_row, startCol = 1)
  openxlsx::addStyle(wb, "SUMMARY", styles$header, rows = start_row, cols = 1:2, gridExpand = TRUE)
  openxlsx::writeData(wb, "SUMMARY", sample_info, startRow = start_row + 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  # Set column widths
  openxlsx::setColWidths(wb, "SUMMARY", cols = 1:2, widths = c(25, 30))
}


# ==============================================================================
# ITEM_SCORES SHEET
# ==============================================================================

#' Write ITEM_SCORES sheet
#' @keywords internal
write_item_scores_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "ITEM_SCORES")

  # Start with count scores
  item_scores <- results$count_scores

  # Add logit utilities if available
  if (!is.null(results$logit_results)) {
    logit_utils <- results$logit_results$utilities[, c("Item_ID", "Logit_Utility", "Logit_SE")]
    item_scores <- merge(item_scores, logit_utils, by = "Item_ID", all.x = TRUE)
  }

  # Add HB utilities if available
  if (!is.null(results$hb_results)) {
    hb_utils <- results$hb_results$population_utilities[,
                  c("Item_ID", "HB_Utility_Mean", "HB_Utility_SD")]
    item_scores <- merge(item_scores, hb_utils, by = "Item_ID", all.x = TRUE)
  }

  # Add rescaled scores
  rescale_method <- config$output_settings$Score_Rescale_Method

  if ("HB_Utility_Mean" %in% names(item_scores)) {
    item_scores$Rescaled_Score <- rescale_utilities(
      item_scores$HB_Utility_Mean, rescale_method
    )
  } else if ("Logit_Utility" %in% names(item_scores)) {
    item_scores$Rescaled_Score <- rescale_utilities(
      item_scores$Logit_Utility, rescale_method
    )
  } else {
    item_scores$Rescaled_Score <- rescale_utilities(
      item_scores$Net_Score, rescale_method
    )
  }

  # Sort by output preference
  sort_order <- config$output_settings$Output_Item_Sort_Order

  sort_col <- switch(sort_order,
    "UTILITY_DESC" = -item_scores$Rescaled_Score,
    "UTILITY_ASC" = item_scores$Rescaled_Score,
    "ITEM_ID" = item_scores$Item_ID,
    "DISPLAY_ORDER" = item_scores$Display_Order,
    -item_scores$Rescaled_Score
  )

  item_scores <- item_scores[order(sort_col), ]

  # Update rank
  item_scores$Rank <- rank(-item_scores$Rescaled_Score, ties.method = "min")

  # Select columns for output
  output_cols <- c(
    "Item_ID", "Item_Label", "Item_Group",
    "Times_Shown", "Times_Best", "Times_Worst",
    "Best_Pct", "Worst_Pct", "Net_Score"
  )

  if ("Logit_Utility" %in% names(item_scores)) {
    output_cols <- c(output_cols, "Logit_Utility", "Logit_SE")
  }

  if ("HB_Utility_Mean" %in% names(item_scores)) {
    output_cols <- c(output_cols, "HB_Utility_Mean", "HB_Utility_SD")
  }

  output_cols <- c(output_cols, "Rescaled_Score", "Rank")
  output_cols <- output_cols[output_cols %in% names(item_scores)]

  output_df <- item_scores[, output_cols]

  # Write data
  openxlsx::writeData(wb, "ITEM_SCORES", output_df, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  # Apply styles
  n_rows <- nrow(output_df)

  # Numeric columns
  numeric_cols <- which(names(output_df) %in%
                         c("Best_Pct", "Worst_Pct", "Net_Score", "Rescaled_Score"))
  for (col in numeric_cols) {
    openxlsx::addStyle(wb, "ITEM_SCORES", styles$number_1dp,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Utility columns
  util_cols <- which(names(output_df) %in%
                      c("Logit_Utility", "Logit_SE", "HB_Utility_Mean", "HB_Utility_SD"))
  for (col in util_cols) {
    openxlsx::addStyle(wb, "ITEM_SCORES", styles$number_3dp,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Integer columns
  int_cols <- which(names(output_df) %in%
                     c("Times_Shown", "Times_Best", "Times_Worst", "Rank"))
  for (col in int_cols) {
    openxlsx::addStyle(wb, "ITEM_SCORES", styles$integer,
                      rows = 2:(n_rows + 1), cols = col, gridExpand = TRUE)
  }

  # Set column widths
  openxlsx::setColWidths(wb, "ITEM_SCORES", cols = 1:ncol(output_df),
                        widths = "auto")
  openxlsx::setColWidths(wb, "ITEM_SCORES", cols = 2, widths = 40)  # Item_Label

  # Freeze header
  openxlsx::freezePane(wb, "ITEM_SCORES", firstRow = TRUE)
}


# ==============================================================================
# SEGMENT_SCORES SHEET
# ==============================================================================

#' Write SEGMENT_SCORES sheet
#' @keywords internal
write_segment_scores_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "SEGMENT_SCORES")

  segment_scores <- results$segment_results$segment_scores

  if (is.null(segment_scores) || nrow(segment_scores) == 0) {
    openxlsx::writeData(wb, "SEGMENT_SCORES", "No segment results available",
                       startRow = 1, startCol = 1)
    return()
  }

  # Select columns
  output_cols <- c(
    "Segment_ID", "Segment_Label", "Segment_Value", "Segment_N",
    "Item_ID", "Item_Label",
    "Times_Shown", "Times_Best", "Times_Worst",
    "Best_Pct", "Worst_Pct", "Net_Score", "Rank"
  )
  output_cols <- output_cols[output_cols %in% names(segment_scores)]

  output_df <- segment_scores[, output_cols]

  # Write data
  openxlsx::writeData(wb, "SEGMENT_SCORES", output_df, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  # Set column widths
  openxlsx::setColWidths(wb, "SEGMENT_SCORES", cols = 1:ncol(output_df),
                        widths = "auto")

  # Freeze header
  openxlsx::freezePane(wb, "SEGMENT_SCORES", firstRow = TRUE)
}


# ==============================================================================
# INDIVIDUAL_UTILS SHEET
# ==============================================================================

#' Write INDIVIDUAL_UTILS sheet
#' @keywords internal
write_individual_utils_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "INDIVIDUAL_UTILS")

  ind_utils <- results$hb_results$individual_utilities

  if (is.null(ind_utils) || nrow(ind_utils) == 0) {
    openxlsx::writeData(wb, "INDIVIDUAL_UTILS", "No individual utilities available",
                       startRow = 1, startCol = 1)
    return()
  }

  # Write data
  openxlsx::writeData(wb, "INDIVIDUAL_UTILS", ind_utils, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  # Set column widths
  openxlsx::setColWidths(wb, "INDIVIDUAL_UTILS", cols = 1:ncol(ind_utils),
                        widths = "auto")

  # Freeze header
  openxlsx::freezePane(wb, "INDIVIDUAL_UTILS", firstRow = TRUE)
}


# ==============================================================================
# MODEL_DIAGNOSTICS SHEET
# ==============================================================================

#' Write MODEL_DIAGNOSTICS sheet
#' @keywords internal
write_diagnostics_sheet <- function(wb, results, config, styles) {

  openxlsx::addWorksheet(wb, "MODEL_DIAGNOSTICS")

  diagnostics_data <- list()

  # Logit model diagnostics
  if (!is.null(results$logit_results)) {
    fit <- results$logit_results$model_fit

    logit_diag <- data.frame(
      Metric = c(
        "Log-Likelihood",
        "Null Log-Likelihood",
        "AIC",
        "BIC",
        "McFadden Pseudo-R2",
        "Number of Parameters",
        "Number of Choice Sets"
      ),
      Value = c(
        round(fit$log_likelihood, 2),
        round(fit$null_log_likelihood, 2),
        round(fit$aic, 2),
        round(fit$bic, 2),
        round(fit$mcfadden_r2, 4),
        fit$n_parameters,
        fit$n_choice_sets
      ),
      stringsAsFactors = FALSE
    )

    diagnostics_data[["Logit Model"]] <- logit_diag
  }

  # HB model diagnostics
  if (!is.null(results$hb_results)) {
    hb_diag <- results$hb_results$diagnostics

    if (!is.null(hb_diag)) {
      hb_df <- data.frame(
        Metric = c(
          "Method",
          "Number of Divergences",
          "Max Treedepth Exceeded",
          "Mean Rhat",
          "Minimum ESS"
        ),
        Value = c(
          results$hb_results$model_fit$method,
          hb_diag$n_divergences %||% "N/A",
          hb_diag$max_treedepth_exceeded %||% "N/A",
          round(hb_diag$mean_rhat %||% NA, 3),
          round(hb_diag$min_ess %||% NA, 0)
        ),
        stringsAsFactors = FALSE
      )

      diagnostics_data[["HB Model"]] <- hb_df
    }
  }

  # Write each section
  current_row <- 1

  for (section_name in names(diagnostics_data)) {
    section_data <- diagnostics_data[[section_name]]

    openxlsx::writeData(wb, "MODEL_DIAGNOSTICS", section_name,
                       startRow = current_row, startCol = 1)
    openxlsx::addStyle(wb, "MODEL_DIAGNOSTICS", styles$header,
                      rows = current_row, cols = 1:2, gridExpand = TRUE)

    openxlsx::writeData(wb, "MODEL_DIAGNOSTICS", section_data,
                       startRow = current_row + 1, startCol = 1,
                       colNames = TRUE, headerStyle = styles$subheader)

    current_row <- current_row + nrow(section_data) + 4
  }

  # Set column widths
  openxlsx::setColWidths(wb, "MODEL_DIAGNOSTICS", cols = 1:2, widths = c(30, 20))
}


# ==============================================================================
# DESIGN SHEETS
# ==============================================================================

#' Write DESIGN sheets
#' @keywords internal
write_design_sheets <- function(wb, results, config, styles) {

  design_result <- results$design_result

  # DESIGN sheet
  openxlsx::addWorksheet(wb, "DESIGN")
  openxlsx::writeData(wb, "DESIGN", design_result$design, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)
  openxlsx::setColWidths(wb, "DESIGN", cols = 1:ncol(design_result$design),
                        widths = "auto")
  openxlsx::freezePane(wb, "DESIGN", firstRow = TRUE)

  # DESIGN_SUMMARY sheet
  openxlsx::addWorksheet(wb, "DESIGN_SUMMARY")

  design_summary <- summarize_design(design_result)

  openxlsx::writeData(wb, "DESIGN_SUMMARY", "Design Summary",
                     startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "DESIGN_SUMMARY", styles$header,
                    rows = 1, cols = 1:2, gridExpand = TRUE)
  openxlsx::writeData(wb, "DESIGN_SUMMARY", design_summary$summary,
                     startRow = 2, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  openxlsx::writeData(wb, "DESIGN_SUMMARY", "Item Frequencies",
                     startRow = nrow(design_summary$summary) + 5, startCol = 1)
  openxlsx::writeData(wb, "DESIGN_SUMMARY", design_summary$item_frequencies,
                     startRow = nrow(design_summary$summary) + 6, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  openxlsx::setColWidths(wb, "DESIGN_SUMMARY", cols = 1:3, widths = c(25, 15, 15))
}


# ==============================================================================
# DESIGN-ONLY OUTPUT
# ==============================================================================

#' Generate design-only Excel output
#'
#' @param design_result List. Output from generate_maxdiff_design
#' @param config List. Configuration object
#' @param verbose Logical. Print messages
#'
#' @return Character. Path to output file
#' @export
generate_design_output <- function(design_result, config, verbose = TRUE) {

  if (verbose) log_message("Generating design output file...", "INFO", verbose)

  # Check openxlsx
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required for Excel output", call. = FALSE)
  }

  # Determine output path
  output_folder <- config$project_settings$Output_Folder
  project_name <- config$project_settings$Project_Name

  if (is.null(output_folder) || !nzchar(output_folder)) {
    output_folder <- config$project_root
  }

  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }

  output_filename <- sprintf("%s_MaxDiff_Design.xlsx", project_name)
  output_path <- file.path(output_folder, output_filename)

  # Create workbook
  wb <- openxlsx::createWorkbook()
  styles <- create_output_styles()

  # DESIGN sheet
  openxlsx::addWorksheet(wb, "DESIGN")
  openxlsx::writeData(wb, "DESIGN", design_result$design, startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)
  openxlsx::setColWidths(wb, "DESIGN", cols = 1:ncol(design_result$design),
                        widths = "auto")
  openxlsx::freezePane(wb, "DESIGN", firstRow = TRUE)

  # DESIGN_SUMMARY sheet
  openxlsx::addWorksheet(wb, "DESIGN_SUMMARY")
  design_summary <- summarize_design(design_result)

  openxlsx::writeData(wb, "DESIGN_SUMMARY", design_summary$summary,
                     startRow = 1, startCol = 1,
                     colNames = TRUE, headerStyle = styles$header)

  openxlsx::writeData(wb, "DESIGN_SUMMARY", "Item Frequencies",
                     startRow = nrow(design_summary$summary) + 3, startCol = 1)
  openxlsx::writeData(wb, "DESIGN_SUMMARY", design_summary$item_frequencies,
                     startRow = nrow(design_summary$summary) + 4, startCol = 1,
                     colNames = TRUE, headerStyle = styles$subheader)

  # Save (TRS v1.0: Use atomic save if available)
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, module = "MAXD")
    if (!save_result$success) {
      stop(sprintf("Failed to save design file: %s", save_result$error), call. = FALSE)
    }
  } else {
    openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
  }

  if (verbose) {
    log_message(sprintf("Design saved: %s", output_path), "INFO", verbose)
  }

  return(output_path)
}


# ==============================================================================
# NULL COALESCE
# ==============================================================================

#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff output module loaded (v%s)", OUTPUT_VERSION))
